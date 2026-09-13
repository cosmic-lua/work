#!/usr/bin/env cosmic
-- `next`'s merge-queue awareness: an accepted item whose PR already
-- reports auto-merge armed, or a `mergeable_state` of "queued", is
-- never offered as the head to finish — GitHub is already landing it.
-- Split from `action_test.tl`, which sits against the file cap, the
-- same reason `action_ci_test.tl` exists. The queue map is exactly the
-- shape `ci` is: read once by the caller (`_work.review.is_queued`
-- over a fetched `_work.gh.pull`), handed in as plain data, so no test
-- here needs a live GitHub read.

local check = require("cosmic.check")
local act = require("_work.action")
local fixture = require("_work.fixture")
local idxmod = require("_work.index")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local review = require("_work.review")

local type Item = item.Item

--- `act.next_action`, over a fresh in-memory index built from `items`.
--- @param items {Item} All items
--- @param specs act.Specs Sidecar body by id
--- @param session string | nil This session's name, "" when unnamed
--- @param merge_queue act.QueueStates | nil Accepted items already queued to merge
--- @return act.Action
local function next_action(items: {Item}, specs: act.Specs,
    session?: string, merge_queue?: act.QueueStates): act.Action
  local c = fixture.make_index(items)
  local a, err = act.next_action(c, items, specs, session, nil, nil, "", nil,
    merge_queue)
  check.must(idxmod.close(c))
  assert(a ~= nil, err)
  return a
end

local counter = 0

--- A fresh deterministic id; later calls sort later, so creation
--- order is age order exactly as live ksuids behave.
local function fresh_id(): string
  counter = counter + 1
  return check.must(ksuid.encode(1700000000 + counter, ("\0"):rep(16)))
end

--- One valid item.
local function make(over: {string: any}): Item
  local t: {string: any} = {id = fresh_id(), title = "item"}
  for k, v in pairs(over or {}) do
    t[k] = v
  end
  return check.must(item.decode(t))
end

--- A ranked outcome: the board it belongs to stands in `items` too,
--- its own `order` naming just this outcome, so everything beneath it
--- — and only it — is ranked.
--- @return Item root
local function placed_root(items: {Item}): Item
  local board = make({})
  local root = make({parent = board.id})
  board.order = {root.id}
  items[#items + 1] = board
  items[#items + 1] = root
  return root
end

local READY < const > = "## Change\nDo this.\n## Non-goals\nNot that.\n"
.. "## Acceptance\n`ci`\n"

local function ready_specs(items: {Item}): act.Specs
  local out: act.Specs = {}
  for _, i in ipairs(items) do
    out[i.id] = READY
  end
  return out
end

-- Auto-merge armed is enough on its own, even with an ordinary
-- `mergeable_state` — the two conditions are an OR. The outcome is
-- deliberately unplaced with an open child (the same shape
-- `action_ci_test.tl` uses) so no intake rung has anything to offer
-- instead.
local function test_auto_merge_armed_is_not_offered()
  local board = make({})
  local root = make({parent = board.id})
  local accepted = make({parent = root.id, claim = "who", pr = 2,
      verdict = "accept"})
  local items: {Item} = {board, root, accepted}
  local specs = ready_specs(items)
  local p: review.Pull = {number = 2, auto_merge = true,
    mergeable_state = "clean"}
  local queue: act.QueueStates = {[accepted.id] = review.is_queued(p)}
  local a = next_action(items, specs, "me", queue)
  assert(a.kind ~= "finish", "an armed auto-merge is not offered: " .. a.kind)
  assert(a.kind == "none", "and nothing else fires either: " .. a.kind)
  assert(a.reason:find("queued", 1, true) ~= nil,
    "the reason names it: " .. a.reason)
end

-- `mergeable_state == "queued"` alone, with no auto-merge field set at
-- all, is the other half of the OR: the repo's merge queue took it.
local function test_mergeable_state_queued_is_not_offered()
  local board = make({})
  local root = make({parent = board.id})
  local accepted = make({parent = root.id, claim = "who", pr = 3,
      verdict = "accept"})
  local items: {Item} = {board, root, accepted}
  local specs = ready_specs(items)
  local p: review.Pull = {number = 3, mergeable_state = "queued"}
  local queue: act.QueueStates = {[accepted.id] = review.is_queued(p)}
  local a = next_action(items, specs, "me", queue)
  assert(a.kind ~= "finish", "a queued mergeable_state is not offered")
end

-- Neither condition holds: the ordinary "accepted, awaiting merge"
-- head is offered exactly as it always was.
local function test_without_either_it_is_offered_as_the_ordinary_finish()
  local items: {Item} = {}
  local root = placed_root(items)
  local accepted = make({parent = root.id, claim = "who", pr = 4,
      verdict = "accept"})
  items[#items + 1] = accepted
  local specs = ready_specs(items)
  local p: review.Pull = {number = 4, mergeable_state = "clean"}
  local queue: act.QueueStates = {[accepted.id] = review.is_queued(p)}
  local a = next_action(items, specs, "me", queue)
  assert(a.kind == "finish" and a.item.id == accepted.id,
    "an unqueued accept is still the head to finish: " .. a.kind)
end

-- A queued accept never crowds out real work: a pullable todo item is
-- still offered ahead of "nothing to do" — `next` falls through to it
-- instead of stalling on an unactionable head.
local function test_a_queued_accept_never_holds_a_pull_back()
  local items: {Item} = {}
  local root = placed_root(items)
  local accepted = make({parent = root.id, claim = "who", pr = 5,
      verdict = "accept"})
  local fresh = make({parent = root.id})
  items[#items + 1] = accepted
  items[#items + 1] = fresh
  local specs = ready_specs(items)
  local queue: act.QueueStates = {[accepted.id] = true}
  local a = next_action(items, specs, "me", queue)
  assert(a.kind == "pull" and a.item.id == fresh.id,
    "a pullable item is still offered: " .. a.kind)
end

-- With no queue map at all — the shape a caller with no GitHub reach
-- passes — an accepted item is offered exactly as it always was.
local function test_no_queue_map_offers_the_finish_as_before()
  local items: {Item} = {}
  local root = placed_root(items)
  local accepted = make({parent = root.id, claim = "who", pr = 6,
      verdict = "accept"})
  items[#items + 1] = accepted
  local a = next_action(items, ready_specs(items), "me")
  assert(a.kind == "finish" and a.item.id == accepted.id,
    "no queue map is not a refusal: " .. a.kind)
end

-- A todo item with an unresolved dependency is never offered as a
-- pull: `depends_on` gates whether it may start, so offering it would
-- hand back a candidate `take` itself refuses. The control is the same
-- board with no edge declared, where the waiter — the older of the two,
-- so the one age order reaches first — IS what comes back: the blocker
-- coming back instead is the skip, not the queue's own ordering.
local function test_a_blocked_todo_item_is_not_offered()
  local frame: {Item} = {}
  local root = placed_root(frame)
  local waiter_id = fresh_id()
  local blocker_id = fresh_id()
  local control: {Item} = {frame[1], frame[2],
    make({parent = root.id, id = waiter_id}),
    make({parent = root.id, id = blocker_id})}
  local first = next_action(control, ready_specs(control), "me")
  assert(first.kind == "pull" and first.item.id == waiter_id,
    "with no edge the queue reaches the waiter first: " .. first.kind
    .. " " .. tostring(first.item and first.item.id))
  local blocked: {Item} = {frame[1], frame[2],
    make({parent = root.id, id = waiter_id, depends_on = blocker_id}),
    make({parent = root.id, id = blocker_id})}
  local a = next_action(blocked, ready_specs(blocked), "me")
  assert(a.kind == "pull" and a.item.id == blocker_id,
    "with it the waiter is skipped and the blocker offered: " .. a.kind
    .. " " .. tostring(a.item and a.item.id))
end

-- Nothing left to offer: the dependency skip is COUNTED and NAMED
-- rather than falling through to a generic "nothing here" — a session
-- reading that needs to see which dependency holds the queue, or the
-- absence looks like a bug. The count names only what it tallied, so
-- the sibling with no dependency is never named beside it. The outcome
-- is deliberately UNRANKED with two open children, the same shape
-- `action_ci_test.tl` uses, so no intake rung fires instead.
local function test_a_blocked_queue_reports_the_dependency_holding_it()
  local board = make({})
  local root = make({parent = board.id})
  -- An id off the board entirely: an unresolved dependency exactly as an
  -- open one is, and it adds no second row to the queue.
  local absent = fresh_id()
  local waiter = make({parent = root.id, depends_on = absent})
  local unblocked = make({parent = root.id})
  local items: {Item} = {board, root, waiter, unblocked}
  local a = next_action(items, ready_specs(items), "me")
  assert(a.kind == "none", "nothing is offered: " .. a.kind)
  assert(a.reason:find("1 item(s) wait on a dependency", 1, true) ~= nil,
    "the count reflects only what was tallied: " .. a.reason)
  assert(a.reason:find(waiter.id:sub(1, 8), 1, true) ~= nil
    and a.reason:find(absent:sub(1, 8), 1, true) ~= nil,
    "the waiter and what holds it are both named: " .. a.reason)
  assert(a.reason:find(unblocked.id:sub(1, 8), 1, true) == nil,
    "an item no dependency holds is never named beside the count: "
    .. a.reason)
end

-- A resolved dependency stops holding anything: the same item, whose
-- blocker is done, is offered exactly as an undeclared one would be.
local function test_a_done_dependency_stops_blocking()
  local items: {Item} = {}
  local root = placed_root(items)
  local blocker = make({parent = root.id, resolution = "completed"})
  local waiter = make({parent = root.id, depends_on = blocker.id})
  items[#items + 1] = blocker
  items[#items + 1] = waiter
  local a = next_action(items, ready_specs(items), "me")
  assert(a.kind == "pull" and a.item.id == waiter.id,
    "a done dependency holds nothing back: " .. a.kind)
end
