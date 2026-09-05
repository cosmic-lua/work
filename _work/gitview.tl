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
local ciobs = require("_work.ciobs")
local flow = require("_work.flow")
local gate = require("_work.gitgate")
local guide = require("_work.guidance")
local health = require("_work.health")
local index = require("_work.index")
local item = require("_work.item")
local act = require("_work.action")
local lanes = require("_work.lanes")
local overlap = require("_work.overlap")
local publish = require("_work.publish")
local read = require("_work.read")
local sess = require("_work.session")
local store = require("_work.store")
local tail = require("_work.tail")

local type Index = index.Index

local verdict_line = gate.verdict_line

--- The board's stale claim and review-claim ages, split by kind —
--- `_work.read.stale`, over the store's own open cache; empty maps on
--- a read failure, since a health report degrades to "unknown" rather
--- than failing the whole render.
--- @param s store.Store The store
--- @return health.StaleAges
local function stale_ages(s: store.Store): health.StaleAges
  local c, _cerr = store.read(s)
  if c == nil then
    return {claim = {}, review = {}}
  end
  local rows, _rerr = read.stale(c)
  if rows == nil then
    return {claim = {}, review = {}}
  end
  return health.from_rows(rows)
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
  local c, _cerr = store.read(s)
  if c == nil then
    return out
  end
  local rows, _qerr = read.queue(c)
  if rows == nil then
    return out
  end
  local stage_by_id: {string: integer} = {}
  for _, row in ipairs(rows) do
    stage_by_id[row.id] = row.stage
  end
  for _, i in ipairs(all) do
    if ciobs.is_candidate(i, stage_by_id) then
      local state, age = ciobs.read(c, i.repo, i.pr)
      if state == nil or not ciobs.fresh(age) then
        state = ciobs.observe(s, c, i.repo, i.pr)
      end
      if state ~= nil then
        out[i.id] = state
      end
    end
  end
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
--- @param c Index An index with `_work.readddl.ensure_views` applied
--- @param all {item.Item} Every item
--- @param specs act.Specs Sidecar body by id
--- @param ages health.Ages Stale claim ages, by id
--- @param lane_facts {string: string} | nil Lane state, nil when unsynced
--- @return {string} | nil The lines to print
--- @return string The verdict detail, or the error on a nil first return
local function status_report(c: Index, all: {item.Item}, specs: act.Specs,
    ages?: health.Ages, lane_facts?: {string: string}):
  {string} | nil, string
  local aged = ages or {}
  local by_id = item.by_id(all)
  -- Selection and stage-bucketing are the `queue` view's own — this
  -- is only the RENDER order laid over what it returns, so every
  -- queue on this page reads in the one order `show ID` describes for
  -- a single item.
  local rows, qerr = read.queue(c)
  if rows == nil then
    return nil, qerr
  end
  local doing: {item.Item} = {}
  local todo: {item.Item} = {}
  for _, row in ipairs(rows) do
    local i = by_id[row.id]
    if i ~= nil then
      if row.stage < flow.STAGE_REPAIR then
        doing[#doing + 1] = i
      else
        todo[#todo + 1] = i
      end
    end
  end
  local out: {string} = {}
  out[#out + 1] = ("%-6s %d/%d"):format("doing", #doing, flow.DOING_LIMIT)
  for _, i in ipairs(doing) do
    local sub, suberr = read.substate(c, i.id)
    if sub == nil then
      return nil, suberr
    end
    local marks = (" [%s]"):format(sub)
    if i.claim ~= "" then marks = marks .. " @" .. i.claim end
    if i.pr ~= 0 then marks = marks .. (" pr:%d"):format(i.pr) end
    if i.result ~= "" then
      marks = marks .. (" result:%s"):format(i.result:sub(1, 7))
    end
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
  local pullable = 0
  local pullable_ids: {string: boolean} = {}
  for _, i in ipairs(todo) do
    local pb, pberr = act.passes_bar(c, i, specs)
    if pberr ~= "" then
      return nil, pberr
    end
    pullable_ids[i.id] = pb
    if pb then
      pullable = pullable + 1
    end
  end
  out[#out + 1] = ("%-6s %d (%d pullable)"):format("todo", #todo, pullable)
  for k = 1, math.min(#todo, TODO_SHOWN) do
    local i = todo[k]
    local marks = ""
    if pullable_ids[i.id] then
      marks = " [pullable]"
    end
    if i.repo ~= "" then marks = marks .. " [" .. i.repo .. "]" end
    out[#out + 1] = ("  %s%s"):format(id_line(i), marks)
  end
  if #todo > TODO_SHOWN then
    out[#out + 1] = ("  ... %d more"):format(#todo - TODO_SHOWN)
  end
  -- Untriaged outcomes render item by item: they are not workable
  -- yet, and this is the one list of them anyone gets.
  local triage, trerr = read.triage(c)
  if triage == nil then
    return nil, trerr
  end
  out[#out + 1] = ("%-6s %d"):format("triage", #triage)
  for _, tid in ipairs(triage) do
    local f = by_id[tid]
    if f ~= nil then
      out[#out + 1] = ("  %s %s"):format(tail.handle(f.id), f.title)
    end
  end
  local structure, sterr = read.structure(c)
  if structure == nil then
    return nil, sterr
  end
  for _, p in ipairs(structure) do
    out[#out + 1] = ("  graph: %s: %s"):format(p.id, p.detail)
  end
  local verdict = ("doing %d/%d"):format(#doing, flow.DOING_LIMIT)
  if #doing >= flow.DOING_LIMIT then
    verdict = ("bound: doing is at %d/%d — finish something before taking "
      .. "more"):format(#doing, flow.DOING_LIMIT)
  end
  if #structure > 0 then
    verdict = ("%s; %d graph problem(s)"):format(verdict, #structure)
  end
  return out, verdict
end

--- `list_via_cache`'s result: every item read off the one open cache —
--- a record rather than a bare list, so a later field can join it
--- without changing every caller's shape.
local record Board
  items: {item.Item}
end

--- Every item via the store's own open cache — `store.list`, which
--- keeps the connection open on `s` for `store.read` to reuse. Kept as
--- its own function, over a bare `store.list`, only for `Board`'s
--- shape and the name `_work/gitview_test.tl` already asserts a
--- process count against.
--- @param s store.Store The store
--- @return Board | nil Every item
--- @return string Error message
local function list_via_cache(s: store.Store): Board | nil, string
  local all, err = store.list(s)
  if all == nil then
    return nil, err
  end
  return {items = all}, ""
end

--- Bare `show`: the whole board. Named `cmd_status` for the report it
--- prints; the verdict line says `show`, the verb that reaches it.
local function cmd_status(s: store.Store): integer
  local board, aerr = list_via_cache(s)
  if board == nil then
    return verdict_line("show", false, aerr)
  end
  local all = board.items
  local c, cerr = store.read(s)
  if c == nil then
    return verdict_line("show", false, cerr)
  end
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
  local lines, verdict = status_report(c, all, read_specs(s, all),
    stale_ages(s).claim, lane_facts)
  if lines == nil then
    return verdict_line("show", false, verdict)
  end
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
--- @param c Index An index with `_work.readddl.ensure_views` applied
--- @param all {item.Item} Every item
--- @param specs act.Specs Sidecar body by id
--- @param session string This session's name, "" when unnamed
--- @param ages health.Ages Stale claim ages, by id
--- @param review_ages health.Ages Stale review ages, by id
--- @return string The action, its target, the rule behind it, and its guidance
--- @return string Error message
local function next_report(c: Index, all: {item.Item}, specs: act.Specs,
    session?: string, ages?: health.Ages, review_ages?: health.Ages): string, string
  -- The session seeds the tie-break, so concurrent sessions asking
  -- the same board fan out across items no judgment separates
  -- instead of converging on one.
  local action, err = act.next_action(c, all, specs, session, ages,
    review_ages, session)
  if action == nil then
    return "", err
  end
  return render_action(action, specs), ""
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
--- @param c Index An index with `_work.readddl.ensure_views` applied
--- @param all {item.Item} Every item
--- @param specs act.Specs Sidecar body by id
--- @param session string This session's name, "" when unnamed
--- @param ages health.Ages Stale claim ages, by id
--- @param review_ages health.Ages Stale review ages, by id
--- @param ci act.CiStates CI state by item id, absent when unknown
--- @return string The action, its target, the rule behind it, and its guidance
--- @return string Error message
local function next_report_live(s: store.Store, c: Index, all: {item.Item},
    specs: act.Specs, session?: string, ages?: health.Ages,
    review_ages?: health.Ages, ci?: act.CiStates): string, string
  local action, err = act.next_action(c, all, specs, session, ages,
    review_ages, session, ci)
  if action == nil then
    return "", err
  end
  if action.kind == "pull" and action.item then
    local events = publish.history(s, action.item.id)
    if events and events[1] then
      action.reason = action.reason .. bounce_note(events[1].subject)
    end
  end
  return render_action(action, specs), ""
end

local function cmd_next(s: store.Store, session?: string): integer
  local board, aerr = list_via_cache(s)
  if board == nil then
    return verdict_line("next", false, aerr)
  end
  local all = board.items
  local c, cerr = store.read(s)
  if c == nil then
    return verdict_line("next", false, cerr)
  end
  local ages = stale_ages(s)
  local report, rerr = next_report_live(s, c, all, read_specs(s, all), session,
    ages.claim, ages.review, ci_states(s, all))
  if rerr ~= "" then
    return verdict_line("next", false, rerr)
  end
  return verdict_line("next", true, report)
end

local record gitview
  type Board = Board
  lanes_row: function(facts: {string: string} | nil): string | nil
  status_report: function(c: Index, all: {item.Item}, specs: act.Specs,
  ages?: health.Ages, lane_facts?: {string: string}):
  {string} | nil, string
  next_report: function(c: Index, all: {item.Item}, specs: act.Specs,
  session?: string, ages?: health.Ages, review_ages?: health.Ages): string, string
  next_report_live: function(s: store.Store, c: Index, all: {item.Item},
  specs: act.Specs, session?: string, ages?: health.Ages,
  review_ages?: health.Ages, ci?: act.CiStates): string, string
  bounce_note: function(subject: string): string
  read_specs: function(s: store.Store, all: {item.Item}): act.Specs
  -- Exported only so `_work/gitview_test.tl` can verify the process
  -- count directly: production code reaches both through `cmd_status`/
  -- `cmd_next`.
  list_via_cache: function(s: store.Store): Board | nil, string
  stale_ages: function(s: store.Store): health.StaleAges
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
  stale_ages = stale_ages,
  cmd_status = cmd_status,
  cmd_next = cmd_next,
}

return M
