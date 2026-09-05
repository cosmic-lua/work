#!/usr/bin/env cosmic
-- `take --pr`: recording a PR as the handover to review. Split from
-- `_work/gitverbs_test.tl`, which sits against the file cap; the rest
-- of `take`/`drop`/`done` lives there.

local check = require("cosmic.check")
local publish = require("_work.publish")
local read = require("_work.read")
local store = require("_work.store")
local fixture = require("_work.fixture")
local verbs = require("_work.gitverbs")

local init_state_repo = fixture.init_state_repo
local commits = fixture.commits
local give_spec = fixture.give_spec
local root_with_leaf = fixture.root_with_leaf

-- `take --pr` is the handover: the PR rides the claim, and a standing
-- send-back clears because the new push is a new head to judge. On a
-- local-only board the GitHub gate stands down.
local function test_take_pr_records_the_handover()
  local s = init_state_repo("handover")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "") == 0)
  assert(verbs.cmd_take(s, leaf, "session-a", 4242, false, "") == 0)
  local got = check.must(store.load(s, leaf))
  assert(got.pr == 4242, "the PR rides the handover: " .. got.pr)
  assert(got.claim == "session-a", "the claim survives it")
  check.must(store.list(s))
  local c = check.must(store.read(s))
  assert(check.must(read.substate(c, got.id)) == "review",
    "and the item awaits a verdict")
end

-- One PR couples one item's verdict: recording a number another OPEN item already carries
-- is refused, naming the holder, and nothing is written to the item that tried.
local function test_take_pr_refuses_a_number_another_item_holds()
  local s = init_state_repo("pr-collision")
  local _, a = root_with_leaf(s)
  local _, b = root_with_leaf(s)
  give_spec(s, a)
  give_spec(s, b)
  assert(verbs.cmd_take(s, a, "session-a", 0, false, "") == 0)
  assert(verbs.cmd_take(s, b, "session-b", 0, false, "") == 0)
  assert(verbs.cmd_take(s, a, "session-a", 7, false, "") == 0)
  assert(verbs.cmd_take(s, b, "session-b", 7, false, "") ~= 0,
    "PR #7 is already A's -- one PR, one item")
  assert(check.must(store.load(s, b)).pr == 0, "and nothing is written")
end

-- Re-recording the item's own number is a no-op, printing store's own line rather than a bespoke one — the collision check never fires against itself.
local function test_take_pr_rerecord_of_its_own_number_stays_a_noop()
  local s = init_state_repo("pr-self-noop")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "") == 0
    and verbs.cmd_take(s, leaf, "session-a", 7, false, "") == 0)
  local before, seen, old_print = commits(s), "", _G.print
  _G.print = function(msg: any) seen = tostring(msg) end
  local again = verbs.cmd_take(s, leaf, "session-a", 7, false, "")
  _G.print = old_print
  assert(again == 0 and commits(s) == before and seen:find("nothing to record", 1, true) ~= nil, seen)
end

-- A DONE item's PR is spent: it does not block another item from recording the same number.
local function test_take_pr_ignores_a_done_items_number()
  local s = init_state_repo("pr-done-spent")
  local _, a = root_with_leaf(s)
  local _, b = root_with_leaf(s)
  give_spec(s, a)
  give_spec(s, b)
  assert(verbs.cmd_take(s, a, "session-a", 0, false, "") == 0)
  assert(verbs.cmd_take(s, a, "session-a", 7, false, "") == 0)
  assert(verbs.cmd_done(s, a, "completed", true, "closing for the fixture") == 0)
  assert(verbs.cmd_take(s, b, "session-b", 0, false, "") == 0)
  assert(verbs.cmd_take(s, b, "session-b", 7, false, "") == 0,
    "A's PR is spent once A is done")
  assert(check.must(store.load(s, b)).pr == 7, "and B's records it")
end

-- --force --why overrides the collision, same as every other refusal
-- here, and the reason rides the commit subject.
local function test_take_pr_collision_forced_lands_with_the_suffix()
  local s = init_state_repo("pr-collision-forced")
  local _, a = root_with_leaf(s)
  local _, b = root_with_leaf(s)
  give_spec(s, a)
  give_spec(s, b)
  assert(verbs.cmd_take(s, a, "session-a", 0, false, "") == 0)
  assert(verbs.cmd_take(s, b, "session-b", 0, false, "") == 0)
  assert(verbs.cmd_take(s, a, "session-a", 7, false, "") == 0)
  assert(verbs.cmd_take(s, b, "session-b", 7, true,
      "repairing a duplicate PR record") == 0,
    "--force --why overrides the collision")
  assert(check.must(store.load(s, b)).pr == 7, "the number lands")
  local events = check.must(publish.history(s, b))
  assert(events[1].subject:find("forced: repairing a duplicate", 1, true),
    "the reason rides the commit: " .. events[1].subject)
end
