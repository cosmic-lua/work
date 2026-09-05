--- The board-wide reads behind `show` (bare) and `next`, split from
--- `_work.gitverbs` (the mutations) so each file stays within the
--- repo's size rule. `show ID`, the read of a single item, is
--- `_work.gitshow` for the same reason. The verdict-line convention
--- is shared through `_work.gitgate`, so reading the board pulls in
--- no mutation code.
---
--- Each read is a PURE report over already-read state plus a `cmd_*`
--- that prints it: what a session reads is the contract, and a report
--- that returns its lines can be asserted on without capturing
--- stdout.
local cache = require("_work.cache")
local cachedb = require("_work.cachedb")
local cachequery = require("_work.cachequery")
local ciobs = require("_work.ciobs")
local flow = require("_work.flow")
local gate = require("_work.gitgate")
local guide = require("_work.guidance")
local health = require("_work.health")
local item = require("_work.item")
local act = require("_work.action")
local lanes = require("_work.lanes")
local overlap = require("_work.overlap")
local prio = require("_work.priority")
local publish = require("_work.publish")
local rank = require("_work.rank")
local refs = require("_work.refs")
local sess = require("_work.session")
local store = require("_work.store")
local tail = require("_work.tail")

local verdict_line = gate.verdict_line

--- Seconds since each claimed item's last board commit. Costs no git
--- process of its own: `list_via_cache` already took one `for-each-ref`
--- snapshot over every watched ref for this render and left its
--- committer dates in `s.touched_at`, so `publish.touched_at` reads
--- that instead of spawning one `for-each-ref` per claimed item.
--- @param s store.Store The store
--- @param all {item.Item} Every item
--- @return health.Ages Ages by item id
local function claim_ages(s: store.Store, all: {item.Item}): health.Ages
  local ages: health.Ages = {}
  local now = os.time()
  for _, i in ipairs(all) do
    if item.is_open(i)
    and ((i.claim or "") ~= "" or (i.reviewer or "") ~= "") then
      local t = publish.touched_at(s, i.id)
      if t ~= nil and t <= now then
        ages[i.id] = now - t
      end
    end
  end
  return ages
end

--- CI check-run state for each open review-stage item that carries a
--- PR, read from `_work.ciobs`'s cached observation — a live
--- `gh.head_checks` call only for a candidate whose row is absent or
--- has aged past the freshness window, never one call per item on
--- every render. A candidate `ciobs` cannot report on (a cache that
--- will not even open, an `observe` failure — no GitHub reach, no
--- origin, no token, a network error) is simply left out of the map —
--- exactly what `action.tl`'s `phased_action` already treats as
--- "unknown", offered the same as it always was.
--- @param s store.Store The store
--- @param all {item.Item} Every item
--- @return act.CiStates CI state by item id
local function ci_states(s: store.Store, all: {item.Item}): act.CiStates
  local out: act.CiStates = {}
  local c, _err = cache.open(s.root)
  if c == nil then
    return out
  end
  for _, i in ipairs(all) do
    if ciobs.is_candidate(i) then
      local state, age = ciobs.read(c, i.repo, i.pr)
      if state == nil or not ciobs.fresh(age) then
        state = ciobs.observe(s, c, i.repo, i.pr)
      end
      if state ~= nil then
        out[i.id] = state
      end
    end
  end
  local _ok, _cerr = cache.close(c)
  return out
end

--- Every spec sidecar, by item id, for the bar checks the reports
--- run. Read once per render, in one batch — `store.read_specs`, not
--- one `read_spec` per item — so a board-wide render stays a fixed
--- number of git processes as the item count grows.
--- @param s store.Store The store
--- @param all {item.Item} Every item
--- @return act.Specs Sidecar body by id
local function read_specs(s: store.Store, all: {item.Item}): act.Specs
  local ids: {string} = {}
  for _, i in ipairs(all) do
    if item.is_open(i) then
      ids[#ids + 1] = i.id
    end
  end
  return store.read_specs(s, ids)
end

--- How many todo lines the board render shows item-by-item. The top
--- of the queue is what a session acts on; the rest is the count.
local TODO_SHOWN < const >: integer = 8

--- The id and title every rendered item line leads with: the id's
--- tail — the last 8 characters, pure entropy and a literal
--- substring of the id — chunked for legibility.
--- @param it item.Item The item
--- @return string "tail-chunked title"
local function id_line(it: item.Item): string
  return ("%s %s"):format(tail.handle(it.id), it.title)
end

--- The lanes row: one `lane=conclusion` pair per required lane, in
--- `lanes.LANES` order, or nil to print no row at all. nil facts is a
--- fresh board that has never synced — silence there, not a row of
--- blanks, is what tells the two states apart.
--- @param facts {string: string} | nil Lane state, nil when unsynced
--- @return string | nil The row, or nil to print nothing
local function lanes_row(facts: {string: string} | nil): string | nil
  if facts == nil then
    return nil
  end
  local parts: {string} = {}
  for _, lane in ipairs(lanes.LANES) do
    local c = facts[lane]
    if c ~= nil and c ~= "" then
      parts[#parts + 1] = ("%s=%s"):format(lane, c)
    end
  end
  return ("%-6s %s"):format("lanes", table.concat(parts, " "))
end

--- The board: doing item by item against the one bound, the top of
--- todo with its pullable marks, the triage queue, and board-wide
--- graph health. Health reports HERE rather than in the spec bar:
--- one item's broken chain is everyone's to see and nobody's reason
--- to be refused a take.
--- @param all {item.Item} Every item
--- @param specs act.Specs Sidecar body by id
--- @param ages health.Ages Seconds since last board commit, by id
--- @param lane_facts {string: string} | nil Lane state, nil when unsynced
--- @param root_order {string} The board's root ranking, in rank order
--- @return {string} The lines to print
--- @return string The verdict detail
local function status_report(all: {item.Item}, specs: act.Specs,
    ages?: health.Ages, lane_facts?: {string: string}, root_order?: {string}):
  {string}, string
  local aged = ages or {}
  local index = flow.by_id(all)
  local pos = prio.positions(all)
  -- Selection and stage-bucketing stay `flow`'s (todo vs. doing, stage
  -- order) — this is only the RENDER order laid over what it returns,
  -- so every queue on this page reads in the one order `show ID`
  -- describes for a single item.
  local ranks = rank.positions(all, root_order or {})
  local out: {string} = {}
  local doing = rank.sorted(flow.in_state(all, "doing", pos), ranks)
  out[#out + 1] = ("%-6s %d/%d"):format("doing", #doing, flow.DOING_LIMIT)
  for _, i in ipairs(doing) do
    local marks = (" [%s]"):format(flow.substate(i))
    if i.claim ~= "" then marks = marks .. " @" .. i.claim end
    if i.pr ~= 0 then marks = marks .. (" pr:%d"):format(i.pr) end
    if i.result ~= "" then
      marks = marks .. (" result:%s"):format(i.result:sub(1, 7))
    end
    if flow.is_blocked(i, index) then marks = marks .. " [blocked]" end
    if i.repo ~= "" then marks = marks .. " [" .. i.repo .. "]" end
    if health.is_stale(i, aged) then
      marks = marks .. (" [claim stale %dh]"):format(
        health.stale_hours(i, aged))
    end
    out[#out + 1] = ("  %s%s"):format(id_line(i), marks)
  end
  local row = lanes_row(lane_facts)
  if row then
    out[#out + 1] = row
  end
  -- A flagged record `list` read past rather than aborting on is
  -- nobody's surprise if nothing says so: one line, board-level like
  -- `lanes`/`todo`, not a mark on the one item among many that carries
  -- it — `""` when nothing was flagged prints nothing at all.
  local flagged = store.flagged_summary(all)
  if flagged ~= "" then
    out[#out + 1] = flagged
  end
  local todo = rank.sorted(flow.in_state(all, "todo", pos), ranks)
  local pullable = 0
  for _, i in ipairs(todo) do
    if act.passes_bar(i, specs, pos) and not flow.is_blocked(i, index) then
      pullable = pullable + 1
    end
  end
  out[#out + 1] = ("%-6s %d (%d pullable)"):format("todo", #todo, pullable)
  for k = 1, math.min(#todo, TODO_SHOWN) do
    local i = todo[k]
    local marks = ""
    if act.passes_bar(i, specs, pos) then
      marks = " [pullable]"
    end
    if flow.is_blocked(i, index) then marks = marks .. " [blocked]" end
    if i.repo ~= "" then marks = marks .. " [" .. i.repo .. "]" end
    out[#out + 1] = ("  %s%s"):format(id_line(i), marks)
  end
  if #todo > TODO_SHOWN then
    out[#out + 1] = ("  ... %d more"):format(#todo - TODO_SHOWN)
  end
  -- Untriaged roots render item by item: they are not workable yet,
  -- and this is the one list of them anyone gets.
  local triage = rank.sorted(flow.untriaged(all), ranks)
  out[#out + 1] = ("%-6s %d"):format("triage", #triage)
  for _, f in ipairs(triage) do
    out[#out + 1] = ("  %s %s"):format(tail.handle(f.id), f.title)
  end
  local graph = flow.graph_problems(all)
  for _, p in ipairs(health.blocker_cycle_problems(all)) do
    graph[#graph + 1] = p
  end
  for _, p in ipairs(graph) do
    out[#out + 1] = "  graph: " .. p
  end
  local verdict = ("doing %d/%d"):format(#doing, flow.DOING_LIMIT)
  local bound = flow.doing_refusal(all)
  if bound then
    verdict = "bound: " .. bound
  end
  if #graph > 0 then
    verdict = ("%s; %d graph problem(s)"):format(verdict, #graph)
  end
  return out, verdict
end

--- `list_via_cache`'s result: every item plus the board's root
--- ranking, read off the one open cache together — a record rather
--- than a third return slot, since slot 1 here admits nil
--- (`guide.lint`'s `fallible-returns` rule).
local record Board
  items: {item.Item}
  root_order: {string}
end

--- Every item via the board cache instead of a fresh git read —
--- `_work.cachequery.items` hydrated straight from `cache.open`'s SQL
--- rows, current for the live board by the same freshness guard
--- `find`/`new` already go through. Neither `cmd_status` nor
--- `cmd_next` writes through `s` afterward, so the lease `store.list`
--- would have set on it is never missed.
---
--- Takes, itself, the `for-each-ref` snapshot `cache.open`'s own guard
--- would otherwise take internally — over `cachedb.WATCH_PATTERNS` —
--- and passes the resulting digest into `cache.open` as `known_digest`
--- so the guard's freshness check reuses it rather than repeating the
--- same process. Keeps every ref's committer date from that one
--- snapshot in `s.touched_at`, so `claim_ages` never has to ask git
--- again for a claimed item's touch time. A snapshot that fails to
--- read is not fatal here: `known_digest` is left nil, and `cache.open`
--- falls back to taking its own. Also reads the board's root ranking
--- off the same open cache, so a render that needs both never pays for
--- a second open.
--- @param s store.Store The store
--- @return Board | nil Every item, and the board's root ranking
--- @return string Error message
local function list_via_cache(s: store.Store): Board | nil, string
  local found, _ferr = refs.for_each_ref(s.root, cachedb.WATCH_PATTERNS)
  local known_digest: string | nil = nil
  if found ~= nil then
    known_digest = cachedb.digest_of(found)
    for _, r in ipairs(found) do
      local id = r.refname:match("^refs/heads/items/(.+)$")
      or r.refname:match("^refs/heads/ended/(.+)$")
      if id then
        s.touched_at[id] = r.touched
      end
    end
  end
  local c, cerr = cache.open(s.root, known_digest)
  if c == nil then
    return nil, cerr
  end
  local all, ierr = cachequery.items(c)
  local root_order, _oerr = cachequery.root_order(c)
  local close_ok, close_err = cache.close(c)
  if all == nil then
    return nil, ierr
  end
  if not close_ok then
    return nil, close_err
  end
  return {items = all, root_order = root_order}, ""
end

--- Bare `show`: the whole board. Named `cmd_status` for the report it
--- prints; the verdict line says `show`, the verb that reaches it.
local function cmd_status(s: store.Store): integer
  local board, aerr = list_via_cache(s)
  if board == nil then
    return verdict_line("show", false, aerr)
  end
  local all = board.items
  -- An unsynced board has no lanes_state.tl at all, and read_state
  -- reports that the same way it reports every lane already at its
  -- last-recorded value: an empty map. That is also, and only, what
  -- a synced-but-all-green board with nothing to say would look
  -- like — except `record` never commits with nothing changed, so an
  -- empty map here means the file was never written.
  local facts = lanes.read_state(s)
  local lane_facts: {string: string} | nil = nil
  if next(facts) ~= nil then
    lane_facts = facts
  end
  local lines, verdict = status_report(all, read_specs(s, all),
    claim_ages(s, all), lane_facts, board.root_order)
  for _, line in ipairs(lines) do
    print(line)
  end
  -- Who the board thinks this session is, printed rather than
  -- documented: the identity decides which work is withheld and which
  -- claims are refused, so a session that cannot see it cannot tell
  -- a healthy board from one that has stopped offering it anything.
  print(sess.note(sess.resolve(nil)))
  return verdict_line("show", true, verdict)
end

--- Renders a decided action: what to do, to what, and under which
--- rule, followed by what the kind MEANS (`_work.guidance`) and any
--- alternates — so a session acts on the answer without going to read
--- prose elsewhere. An alternate that names an item whose Change
--- section names the same file as another open item's carries that
--- collision inline, the same fact `show ID` would print on a
--- separate line — an orchestrator weighing the alternates sees it
--- without a `show` per candidate.
--- @param action act.Action The decision
--- @param specs act.Specs Sidecar body by id, open items only
--- @return string The action, its target, the rule behind it, and its guidance
local function render_action(action: act.Action, specs: act.Specs): string
  local target = ""
  if action.item then
    target = " " .. id_line(action.item)
  end
  local out: {string} = {
    ("%s%s — %s"):format(action.kind, target, action.reason),
  }
  for _, line in ipairs(guide.lines(action.kind, action.item)) do
    out[#out + 1] = "  " .. line
  end
  for _, alt in ipairs(action.alternates or {}) do
    if alt.item then
      local line = ("  or: %s %s"):format(alt.kind, id_line(alt.item))
      local ov = overlap.inline(alt.item.id, specs)
      if ov ~= "" then
        line = line .. " — " .. ov
      end
      out[#out + 1] = line
    end
  end
  return table.concat(out, "\n")
end

--- The one next action, as the verdict detail. Acting on it moves
--- the board, so a session taking several asks again after each one
--- rather than reading a list. A `none` names the fact that binds,
--- which is the diagnosis a session reports.
--- @param all {item.Item} Every item
--- @param specs act.Specs Sidecar body by id
--- @param session string This session's name, "" when unnamed
--- @param ages health.Ages Seconds since last board commit, by id
--- @return string The action, its target, the rule behind it, and its guidance
local function next_report(all: {item.Item}, specs: act.Specs,
    session?: string, ages?: health.Ages): string
  -- The session seeds the tie-break, so concurrent sessions asking
  -- the same board fan out across items no judgment separates
  -- instead of converging on one.
  return render_action(act.next_action(all, specs, session, ages, session), specs)
end

--- The reason named by an item's most recent board commit, when that
--- commit was a drop (`drop ID: <why>` — the lease returned, the item
--- re-offered as-is) rather than a take or a reviewer's release
--- (`drop ID review: <why>` — the review comes free again, but the
--- build was never dropped). A drop's why is worker-side by contract
--- (an item that cannot proceed is blocked on its question instead),
--- so surfacing it tells the next session which side stopped.
--- @param subject string The most recent board-commit subject
--- @return string " (last drop: <why>)", or "" when it was not one
local function bounce_note(subject: string): string
  local why = subject:match("^drop %S+: (.+)$")
  if why == nil then
    return ""
  end
  return (" (last drop: %s)"):format(why)
end

--- `next_report`, but for a decided `pull` the reason carries the
--- why named by the item's last drop, read once for the one decided
--- action rather than once per candidate: a session offered an item
--- that bounced sees why it came back before claiming it.
--- @param s store.Store The store
--- @param all {item.Item} Every item
--- @param specs act.Specs Sidecar body by id
--- @param session string This session's name, "" when unnamed
--- @param ages health.Ages Seconds since last board commit, by id
--- @param ci act.CiStates CI state by item id, absent when unknown
--- @return string The action, its target, the rule behind it, and its guidance
local function next_report_live(s: store.Store, all: {item.Item},
    specs: act.Specs, session?: string, ages?: health.Ages,
    ci?: act.CiStates): string
  local action = act.next_action(all, specs, session, ages, session, ci)
  if action.kind == "pull" and action.item then
    local events = publish.history(s, action.item.id)
    if events and events[1] then
      action.reason = action.reason .. bounce_note(events[1].subject)
    end
  end
  return render_action(action, specs)
end

local function cmd_next(s: store.Store, session?: string): integer
  local board, aerr = list_via_cache(s)
  if board == nil then
    return verdict_line("next", false, aerr)
  end
  local all = board.items
  return verdict_line("next", true,
    next_report_live(s, all, read_specs(s, all), session, claim_ages(s, all),
      ci_states(s, all)))
end

local record gitview
  type Board = Board
  lanes_row: function(facts: {string: string} | nil): string | nil
  status_report: function(all: {item.Item}, specs: act.Specs,
  ages?: health.Ages, lane_facts?: {string: string}, root_order?: {string}):
  {string}, string
  next_report: function(all: {item.Item}, specs: act.Specs,
  session?: string, ages?: health.Ages): string
  next_report_live: function(s: store.Store, all: {item.Item},
  specs: act.Specs, session?: string, ages?: health.Ages,
  ci?: act.CiStates): string
  bounce_note: function(subject: string): string
  read_specs: function(s: store.Store, all: {item.Item}): act.Specs
  -- Exported only so `_work/gitview_test.tl` can verify the process
  -- count directly: production code reaches both through `cmd_status`/
  -- `cmd_next`.
  list_via_cache: function(s: store.Store): Board | nil, string
  claim_ages: function(s: store.Store, all: {item.Item}): health.Ages
  cmd_status: function(s: store.Store): integer
  cmd_next: function(s: store.Store, session?: string): integer
end

local M: gitview = {
  lanes_row = lanes_row,
  status_report = status_report,
  next_report = next_report,
  next_report_live = next_report_live,
  bounce_note = bounce_note,
  read_specs = read_specs,
  list_via_cache = list_via_cache,
  claim_ages = claim_ages,
  cmd_status = cmd_status,
  cmd_next = cmd_next,
}

return M
