#!/usr/bin/env cosmic
-- `gitboard handoff`'s composition: which half it runs, and what it does
-- with a set that is partly already transferred. The claim transfer itself
-- is `_work/stateclaim_handoff_test.tl`; this pins the verb around it.

local check = require("cosmic.check")
local claim = require("_work.claim")
local boardread = require("_work.boardread")
local fixture = require("_work.fixture")
local flow = require("_work.commit_flow_fixture")
local gitreview = require("_work.gitreview")
local stateclaim = require("_work.stateclaim")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

-- These drive the composition, not the checkout: `no-worktree` keeps the
-- brief half from building a real worktree the fixture has no product for.
local function resolver(): function(string): string | nil, string
  return function(x: string): string | nil, string return x, "" end
end

--- An item claimed by the builder and handed over, so it is a legitimate
--- handoff target.
local function awaiting_review(name: string): store.Store, string
  local s, id, p = flow.fresh(name)
  assert(flow.claim(s, id, flow.BUILDER, p) == 0, "builder claims it")
  assert(flow.handover(s, id, flow.BUILDER, p, p.head) == 0, "and hands over")
  return s, id
end

local function holder_of(s: store.Store, id: string): string
  local view = check.must(boardread.list(s.root, s.state_head))
  local lease = view.claims_by_id[id]
  if lease == nil then return "" end
  if claim.status(stateclaim.state(lease), os.time()) ~= "active" then
    return ""
  end
  return lease.holder
end

local function test_handoff_transfers_when_the_caller_does_not_hold_it()
  local s, id = awaiting_review("compose-transfer")
  local code = gitreview.cmd_review(s, {id}, "origin", resolver(),
    {session = flow.REVIEWER}, {["no-worktree"] = true})
  assert(code == 0 or code == 2, "prepared, got " .. tostring(code))
  assert(holder_of(s, id) == flow.REVIEWER,
    "the reviewer holds it, got " .. holder_of(s, id))
end

local function test_a_set_already_held_runs_the_brief_half_not_a_transfer()
  local s, id = awaiting_review("compose-second")
  assert(gitreview.cmd_review(s, {id}, "origin", resolver(), {session = flow.REVIEWER}, {["no-worktree"] = true}) ~= 1, "first call transfers")
  -- Second call with the same set: the transfer half would refuse the whole
  -- batch ("already claimed by this session"), so it must not be attempted.
  local code = gitreview.cmd_review(s, {id}, "origin", resolver(),
    {session = flow.REVIEWER}, {["no-worktree"] = true})
  assert(code ~= 1, "the brief half runs instead of a refused transfer")
end

local function test_a_mixed_set_still_transfers_the_ones_not_yet_held()
  -- The regression that drove this test: a claim batch is atomic, so one
  -- member the caller already holds refused the WHOLE set and the other
  -- item never moved — defeating the batching this verb exists for.
  local s, first = awaiting_review("compose-mixed")
  local _root, second = fixture.root_with_leaf(s)
  fixture.give_spec(s, second)
  local it = check.must(store.load(s, second))
  it.repo, it.base = "acme/widgets", "main"
  assert(storewrite.save(s, it, "set product repository"))
  fixture.caller_publish(s)
  local p2 = flow.product("compose-mixed-second")
  assert(flow.claim(s, second, flow.BUILDER, p2) == 0, "builder claims it")
  assert(flow.handover(s, second, flow.BUILDER, p2, p2.head) == 0, "hands over")
  assert(gitreview.cmd_review(s, {first}, "origin", resolver(), {session = flow.REVIEWER}, {["no-worktree"] = true}) ~= 1, "first is transferred alone")
  assert(holder_of(s, first) == flow.REVIEWER, "and is held")
  local code = gitreview.cmd_review(s, {first, second}, "origin", resolver(),
    {session = flow.REVIEWER}, {["no-worktree"] = true})
  assert(code ~= 1,
    "a mixed set is not rejected whole, got " .. tostring(code))
  assert(holder_of(s, second) == flow.REVIEWER,
    "and the not-yet-held member actually moved")
end

local function test_no_ids_is_refused()
  local s = flow.fresh("compose-empty")
  assert(gitreview.cmd_review(s, {}, "origin", resolver(), {session = flow.REVIEWER}, {["no-worktree"] = true}) == 1, "an empty set is refused")
end

local function test_an_unresolvable_id_refuses_naming_it()
  local s = flow.fresh("compose-badid")
  local code = gitreview.cmd_review(s, {"nope"}, "origin", resolver(),
    {session = flow.REVIEWER}, {["no-worktree"] = true})
  assert(code ~= 0, "an id that is not an item does not prepare")
end

local function test_a_refusal_names_the_item_not_the_batch()
  -- The spec asks for this by name: when one member of a set is not in
  -- review, the caller must learn WHICH. `stateclaim_cli` prints one
  -- `refused <id>: <why>` line per member, so the batch verdict never
  -- swallows the identity of the member that blocked it.
  local s, ready = awaiting_review("compose-named")
  local _root, unready = fixture.root_with_leaf(s)
  fixture.give_spec(s, unready)
  local it = check.must(store.load(s, unready))
  it.repo, it.base = "acme/widgets", "main"
  assert(storewrite.save(s, it, "set product repository"))
  fixture.caller_publish(s)
  -- `unready` has no handover, so it is not awaiting review.
  local code = gitreview.cmd_review(s, {ready, unready}, "origin", resolver(),
    {session = flow.REVIEWER}, {["no-worktree"] = true})
  assert(code ~= 0, "a set carrying a non-review member does not prepare")
  assert(holder_of(s, ready) ~= flow.REVIEWER,
    "and the batch is atomic: the ready member did not move either")
end
