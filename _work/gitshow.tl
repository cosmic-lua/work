--- The `show ID` verb: one item rendered whole — fields, derived
--- state, rank, spec, history, and the same problem list
--- `take` enforces as its spec bar, so what would refuse a pull is
--- visible on the read that precedes it. Its own module rather than a
--- third report inside `_work.gitview`, which sits against the repo's
--- 500-line rule.
---
--- Like every read verb, the report is PURE over already-read state
--- and the `cmd_` half owns the store reads: what a session reads is
--- the contract, and a report that returns its lines can be asserted
--- on without capturing stdout.
local cache = require("_work.cache")
local gate = require("_work.gitgate")
local gitready = require("_work.gitready")
local index = require("_work.index")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local overlap = require("_work.overlap")
local publish = require("_work.publish")
local read = require("_work.read")
local spec = require("_work.spec")
local store = require("_work.store")
local tail = require("_work.tail")

local type Index = index.Index

local verdict_line = gate.verdict_line

--- Mirrors `_work.tail.handle`'s 8-character convention (guillemet-
--- wrapped, underscore-divided tail) without requiring that module.
--- @param id string A full item id (a 27-char KSUID)
--- @return string "«XXXX_XXXX»"
local function handle_of(id: string): string
  local t = id:sub(20)
  return "«" .. t:sub(1, 4) .. "_" .. t:sub(5, 8) .. "»"
end

--- The render for one item's rank: "3 of 7 under «HANDLE»" for an item
--- under an ordinary parent (7 = how many of its siblings are
--- positioned), "outcome 2 of 5" for a direct child of the board, "the
--- board" for the board itself, or "unranked" when the item's own
--- parent has no position for it. `_work.read.children`'s own
--- `position` is already the 1-based dense rank this renders.
--- @param c Index An index with `_work.readddl.ensure_views` applied
--- @param it item.Item The item
--- @return string
--- @return string Error message
local function describe(c: Index, it: item.Item): string, string
  if (it.parent or "") == "" then
    return "the board", ""
  end
  -- Ranked/unranked here is about THIS item's own position among its
  -- OWN direct parent's children — `read.is_ranked` answers a
  -- different question (whether the item's OUTCOME, several levels
  -- up, is placed on the board at all), so it cannot stand in: an
  -- item can sit under a placed outcome and still have no position of
  -- its own where its immediate siblings are ordered.
  local siblings, cherr = read.children(c, it.parent)
  if siblings == nil then
    return "", cherr
  end
  local total = 0
  local own_position: integer | nil = nil
  for _, ch in ipairs(siblings) do
    if ch.position ~= nil then
      total = total + 1
      if ch.child == it.id then
        own_position = ch.position
      end
    end
  end
  if own_position == nil then
    return "unranked", ""
  end
  local parent_role, prerr = read.role(c, it.parent)
  if parent_role == nil then
    return "", prerr
  end
  if parent_role == "board" then
    return ("outcome %d of %d"):format(own_position, total), ""
  end
  return ("%d of %d under %s"):format(own_position, total,
    handle_of(it.parent)), ""
end

--- One word for where an item stands: how it ended, else its derived
--- state while in flight, else todo.
--- @param c Index An index with `_work.index`'s base DDL applied
--- @param it item.Item The item
--- @return string The state
--- @return string Error message
local function state_of(c: Index, it: item.Item): string, string
  if (it.resolution or "") ~= "" then
    return it.resolution, ""
  end
  local st, serr = read.state(c, it.id)
  if st == nil then
    return "", serr
  end
  if st ~= "doing" then
    return "todo", ""
  end
  local sub, suberr = read.substate(c, it.id)
  if sub == nil then
    return "", suberr
  end
  return sub, ""
end

--- One item's fields, role, spec, spec-bar problems, children, and
--- history — every value the `cmd_` half already read, so this stays
--- pure over already-read state.
--- @param it item.Item The item
--- @param role string Its role (`_work.read.role`)
--- @param rank_line string Its rank, rendered (`describe`)
--- @param state string Its one-word state (`state_of`)
--- @param body string Its spec sidecar, "" when it has none
--- @param events {publish.Event} Its git history, newest first
--- @param problems {string} The take gate's problem list, possibly empty
--- @param children_lines {string} Its own open children, rank order,
--- one rendered line each (`_work.read.children`)
--- @param overlaps {string} `_work.overlap`'s pre-rendered lines, possibly empty
--- @return {string} The lines to print
--- @return string The verdict detail
local function show_report(it: item.Item, role: string, rank_line: string,
    state: string, body: string, events: {publish.Event}, problems: {string},
    children_lines: {string}, overlaps?: {string}): {string}, string
  local out: {string} = {("%s %s [%s]"):format(tail.handle(it.id), it.title,
      it.id)}
  out[#out + 1] = ("role: %s"):format(role)
  local seconds = ksuid.time_of(it.id)
  if seconds then
    out[#out + 1] = ("opened: %s"):format(
      os.date("!%Y-%m-%dT%H:%M:%SZ", seconds))
  end
  if it.parent ~= "" then out[#out + 1] = ("parent: %s"):format(it.parent) end
  if it.repo ~= "" then out[#out + 1] = ("repo: %s"):format(it.repo) end
  if it.base ~= "" then out[#out + 1] = ("base: %s"):format(it.base) end
  if item.is_open(it) and role == "work" then
    out[#out + 1] = ("state: %s"):format(state)
  end
  out[#out + 1] = ("rank: %s"):format(rank_line)
  if #children_lines > 0 then
    out[#out + 1] = "children:"
    for _, line in ipairs(children_lines) do
      out[#out + 1] = line
    end
  end
  if it.claim ~= "" then out[#out + 1] = ("claim: %s"):format(it.claim) end
  if it.reviewer ~= "" then
    out[#out + 1] = ("reviewer: %s"):format(it.reviewer)
  end
  if it.pr ~= 0 then out[#out + 1] = ("pr: #%d"):format(it.pr) end
  -- A research handover's deliverable is the spec at a revision, so
  -- the digest prints where a diff's PR number would: the seven hex
  -- the log line and a verdict's `--head` carry.
  if it.result ~= "" then
    out[#out + 1] = ("result: %s"):format(it.result:sub(1, 7))
  end
  if it.verdict ~= "" then
    -- A verdict judges a head AND the spec that head is measured
    -- against, so the head alone cannot answer the question a
    -- re-reviewer asks here: is there anything new to see? A rework
    -- that answers a bounce on the spec moves the sidecar and no
    -- commit, and reading an unmoved head as "nothing happened" is
    -- exactly the mistake. An unrecorded revision says nothing rather
    -- than guessing: the line then reads as it always did.
    local moved = ""
    if (it.verdict_spec or "") ~= "" then
      moved = ", spec unchanged since"
      if spec.revision(body) ~= it.verdict_spec then
        moved = ", spec changed since"
      end
    end
    -- A handover's verdict carries no head — `verdict` leaves it ""
    -- for a PR-less item — so the line cites the recorded digest
    -- where a diff's verdict cites the head it judged.
    if it.result ~= "" then
      out[#out + 1] = ("verdict: %s (result %s%s)"):format(it.verdict,
        it.result:sub(1, 7), moved)
    else
      out[#out + 1] = ("verdict: %s (head %s%s)"):format(it.verdict,
        it.verdict_head, moved)
    end
  end
  if it.resolution ~= "" then
    out[#out + 1] = ("resolution: %s"):format(it.resolution)
  end
  -- The take gate's own problem list, printed on the read that
  -- precedes the pull: what would refuse `take` is nobody's surprise.
  for _, p in ipairs(problems) do
    out[#out + 1] = "bar: " .. p
  end
  -- `decode`'s own tolerance snapshot, beside the bar problems: a
  -- flagged record read past silently teaches nobody it needs repair,
  -- so the read that shows everything else about the item shows this
  -- too (`set --title` and friends fix it, but only once seen).
  for _, p in ipairs(it.decode_problems or {}) do
    out[#out + 1] = "flagged: " .. p
  end
  -- Another open item naming the same file under its own `## Change`
  -- is a collision an orchestrator would otherwise find only by
  -- reading every candidate's spec by hand — see `_work.overlap`.
  for _, line in ipairs(overlaps or {}) do
    out[#out + 1] = line
  end
  if body ~= "" then
    out[#out + 1] = "--- spec ---"
    out[#out + 1] = (body:gsub("\n$", ""))
  end
  for _, e in ipairs(events) do
    out[#out + 1] = ("  %s %s %s"):format(e.at, e.sha, e.subject)
  end
  return out, ("%s is %s"):format(it.id:sub(1, 8), state)
end

--- Print one item.
--- @param s store.Store The store
--- @param id string The item id or an unambiguous prefix
--- @return integer Exit code
local function cmd_show(s: store.Store, id: string): integer
  -- The target item itself still comes from `store.load`, not the
  -- cache: a resolved id's lease (`resolve_id`'s own glob or prefix
  -- match) is what lets `publish.history` below skip its own
  -- exact-ref `for-each-ref` — a lease the cache carries no ref/sha
  -- column to preserve. Every other read here — role, rank, children,
  -- overlap context — goes through `store.list`/`store.read`'s open
  -- cache, the one path every verb reads through.
  local it, lerr = store.load(s, id)
  if it == nil then
    return verdict_line("show", false, lerr)
  end
  local all, aerr = store.list(s)
  if all == nil then
    return verdict_line("show", false, aerr)
  end
  local c, cerr = store.read(s)
  if c == nil then
    return verdict_line("show", false, cerr)
  end
  -- `store.load` above just proved `id` is a real git ref, so a
  -- derived row missing for it is the cache stale in a way its own
  -- digest guard cannot see (nothing moved a WATCHED ref) — a rebuild
  -- forces it back in step, the same repair `cache.open`'s own
  -- `heal()` applies for other kinds of corruption. A second miss
  -- means the row is genuinely never coming, and the read below fails
  -- for real.
  local has_row, _hrerr = read.role(c, id)
  if has_row == nil then
    local _cok, _cerr = store.close(s)
    local rebuilt, rberr = cache.rebuild(s.root)
    if rebuilt == nil then
      return verdict_line("show", false, rberr)
    end
    local _rcok, _rcerr = cache.close(rebuilt)
    local fresh, ferr = store.read(s)
    if fresh == nil then
      return verdict_line("show", false, ferr)
    end
    c = fresh
  end
  -- `git log` is the one read the load never carries — the item's
  -- history lives only in its commits, so this stays a deliberate
  -- process rather than folding into a batch.
  local events, herr = publish.history(s, id)
  if events == nil then
    return verdict_line("show", false, herr)
  end
  local problems: {string} = {}
  local overlaps: {string} = {}
  local body = ""
  if item.is_open(it) then
    -- This item's spec and every OTHER open item's, read in ONE batch
    -- (`store.read_specs`) rather than a single `cat-file -p` for this
    -- one plus a separate batch for the rest, so `_work.overlap` (and
    -- `ready_problems` below, handed the same body) never re-reads a
    -- spec this call already has.
    local ids: {string} = {id}
    for _, other in ipairs(all) do
      if other.id ~= it.id and item.is_open(other) then
        ids[#ids + 1] = other.id
      end
    end
    local bodies = store.read_specs(s, ids)
    body = bodies[it.id] or ""
    problems = gitready.ready_problems(s, it, body)
    overlaps = overlap.lines(it.id, bodies)
  else
    body = store.read_spec(s, id)
  end
  local role, rerr = read.role(c, it.id)
  if role == nil then
    return verdict_line("show", false, rerr)
  end
  local rank_line, rkerr = describe(c, it)
  if rkerr ~= "" then
    return verdict_line("show", false, rkerr)
  end
  local state, sterr = state_of(c, it)
  if sterr ~= "" then
    return verdict_line("show", false, sterr)
  end
  local child_rows, cherr = read.children(c, it.id)
  if child_rows == nil then
    return verdict_line("show", false, cherr)
  end
  local by_id = item.by_id(all)
  local children_lines: {string} = {}
  for _, ch in ipairs(child_rows) do
    if ch.open then
      local title = ""
      local child_it = by_id[ch.child]
      if child_it ~= nil then
        title = child_it.title
      end
      children_lines[#children_lines + 1] = ("  %s %s"):format(
        tail.handle(ch.child), title)
    end
  end
  local lines, verdict = show_report(it, role, rank_line, state, body, events,
    problems, children_lines, overlaps)
  for _, line in ipairs(lines) do
    print(line)
  end
  return verdict_line("show", true, verdict)
end

local record gitshow
  describe: function(c: Index, it: item.Item): string, string
  state_of: function(c: Index, it: item.Item): string, string
  show_report: function(it: item.Item, role: string, rank_line: string,
  state: string, body: string,
  events: {publish.Event}, problems: {string}, children_lines: {string},
  overlaps?: {string}): {string}, string
  cmd_show: function(s: store.Store, id: string): integer
end

local M: gitshow = {
  describe = describe,
  state_of = state_of,
  show_report = show_report,
  cmd_show = cmd_show,
}

return M
