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
local cachequery = require("_work.cachequery")
local flow = require("_work.flow")
local gate = require("_work.gitgate")
local gitready = require("_work.gitready")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local overlap = require("_work.overlap")
local publish = require("_work.publish")
local rank = require("_work.rank")
local spec = require("_work.spec")
local store = require("_work.store")
local tail = require("_work.tail")

local verdict_line = gate.verdict_line

--- One word for where an item stands: how it ended, else its derived
--- state while in flight, else todo.
--- @param it item.Item The item
--- @return string The state
local function state_of(it: item.Item): string
  if (it.resolution or "") ~= "" then
    return it.resolution
  end
  if flow.is_doing(it) then
    return flow.substate(it)
  end
  return "todo"
end

--- One item's fields, role, spec, spec-bar problems, and history.
--- @param it item.Item The item
--- @param all {item.Item} Every item
--- @param ranks {string: rank.Rank} Rank by item id (`rank.positions`)
--- @param body string Its spec sidecar, "" when it has none
--- @param events {publish.Event} Its git history, newest first
--- @param problems {string} The take gate's problem list, possibly empty
--- @param overlaps {string} `_work.overlap`'s pre-rendered lines, possibly empty
--- @return {string} The lines to print
--- @return string The verdict detail
local function show_report(it: item.Item, all: {item.Item},
    ranks: {string: rank.Rank}, body: string,
    events: {publish.Event}, problems: {string},
    overlaps?: {string}): {string}, string
  local out: {string} = {("%s %s [%s]"):format(tail.handle(it.id), it.title,
      it.id)}
  out[#out + 1] = ("role: %s"):format(flow.role(it, all))
  local seconds = ksuid.time_of(it.id)
  if seconds then
    out[#out + 1] = ("opened: %s"):format(
      os.date("!%Y-%m-%dT%H:%M:%SZ", seconds))
  end
  if it.parent ~= "" then out[#out + 1] = ("parent: %s"):format(it.parent) end
  if it.repo ~= "" then out[#out + 1] = ("repo: %s"):format(it.repo) end
  if it.base ~= "" then out[#out + 1] = ("base: %s"):format(it.base) end
  if item.is_open(it) and flow.role(it, all) == "work" then
    out[#out + 1] = ("state: %s"):format(state_of(it))
  end
  out[#out + 1] = ("rank: %s"):format(rank.describe(ranks, all, it.id))
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
  return out, ("%s is %s"):format(it.id:sub(1, 8), state_of(it))
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
  -- column to preserve — and a cache silently missing exactly this
  -- row (stale in a way its own digest guard cannot catch) must never
  -- read as "no such item" for the one item a session named directly.
  -- Only `all` — every OTHER item, for role/rank/overlap context —
  -- comes from the cache; that whole-board read is `store.list`'s
  -- expensive half, not this one.
  local it, lerr = store.load(s, id)
  if it == nil then
    return verdict_line("show", false, lerr)
  end
  local c, cerr = cache.open(s.root)
  if c == nil then
    return verdict_line("show", false, cerr)
  end
  local all, aerr = cachequery.items(c)
  local root_order, _oerr = cachequery.root_order(c)
  local close_ok, close_err = cache.close(c)
  if all == nil then
    return verdict_line("show", false, aerr)
  end
  if not close_ok then
    return verdict_line("show", false, close_err)
  end
  local ranks = rank.positions(all, root_order)
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
    problems = gitready.ready_problems(s, it, all, root_order, body)
    overlaps = overlap.lines(it.id, bodies)
  else
    body = store.read_spec(s, id)
  end
  local lines, verdict = show_report(it, all, ranks, body, events, problems,
    overlaps)
  for _, line in ipairs(lines) do
    print(line)
  end
  return verdict_line("show", true, verdict)
end

local record gitshow
  show_report: function(it: item.Item, all: {item.Item},
  ranks: {string: rank.Rank}, body: string,
  events: {publish.Event}, problems: {string},
  overlaps?: {string}): {string}, string
  cmd_show: function(s: store.Store, id: string): integer
end

local M: gitshow = {
  show_report = show_report,
  cmd_show = cmd_show,
}

return M
