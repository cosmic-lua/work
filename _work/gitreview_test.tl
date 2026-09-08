#!/usr/bin/env cosmic
-- Review uses the same whole-item lease as build and landing. Roles change by
-- explicit drop/acquire, and concurrent reviewers contend on one item ref.
local check = require("cosmic.check")
local flow = require("_work.commit_flow_fixture")
local done = require("_work.gitdone")
local store = require("_work.store")
local verdict = require("_work.gitverdict")

local function awaiting_review(name: string): store.Store, string,
  flow.Product
  local s, id, p = flow.fresh(name)
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  assert(flow.handover(s, id, flow.BUILDER, p, p.head) == 0)
  assert(flow.claim(s, id, flow.BUILDER, p, "drop") == 0)
  return s, id, p
end

local function test_a_live_review_claim_excludes_another_caller()
  local s, id, p = awaiting_review("review-exclusive")
  assert(flow.claim(s, id, flow.REVIEWER, p) == 0)
  assert(flow.claim(s, id, flow.OTHER, p) ~= 0)
  assert(check.must(store.load(s, id)).claim == flow.REVIEWER)
end
test_a_live_review_claim_excludes_another_caller()

local function test_force_cannot_take_over_a_live_review()
  local s, id, p = awaiting_review("review-force")
  assert(flow.claim(s, id, flow.REVIEWER, p) == 0)
  assert(flow.claim(s, id, flow.OTHER, p, "take", true, "") ~= 0)
  assert(flow.claim(s, id, flow.OTHER, p, "take", true,
      "reviewer stopped") ~= 0)
  assert(check.must(store.load(s, id)).claim == flow.REVIEWER)
end
test_force_cannot_take_over_a_live_review()

local function test_review_acquisition_never_adds_a_builder()
  local s, id, p = awaiting_review("review-involvement")
  local before = check.must(store.load(s, id))
  assert(#before.builders == 1 and before.builders[1] == flow.BUILDER)
  assert(flow.claim(s, id, flow.REVIEWER, p) == 0)
  local after = check.must(store.load(s, id))
  assert(#after.builders == 1 and after.builders[1] == flow.BUILDER)
end
test_review_acquisition_never_adds_a_builder()

local function test_builder_cannot_review_its_own_handover()
  local s, id, p = awaiting_review("review-distance")
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  assert(verdict.cmd_verdict_commit(s, id, "accept", p.head,
      flow.BUILDER, false, "", p.root) ~= 0)
  assert(flow.claim(s, id, flow.BUILDER, p, "drop") == 0)
  assert(flow.claim(s, id, flow.REVIEWER, p) == 0)
  assert(verdict.cmd_verdict_commit(s, id, "accept", p.head,
      flow.REVIEWER, false, "", p.root) == 0)
end
test_builder_cannot_review_its_own_handover()

local function test_verdict_and_done_do_not_implicitly_release()
  local s, id, p = awaiting_review("review-explicit-release")
  assert(flow.claim(s, id, flow.REVIEWER, p) == 0)
  assert(verdict.cmd_verdict_commit(s, id, "accept", p.head,
      flow.REVIEWER, false, "", p.root) == 0)
  assert(check.must(store.load(s, id)).claim == flow.REVIEWER)
  assert(flow.claim(s, id, flow.LANDER, p) ~= 0,
    "landing cannot steal the reviewer's live claim")
  assert(flow.claim(s, id, flow.REVIEWER, p, "drop") == 0)
  assert(flow.claim(s, id, flow.LANDER, p) == 0)
  assert(done.cmd_done(s, id, "completed", false, "", "", p.head,
      p.root, flow.LANDER) == 0)
  assert(check.must(store.load(s, id)).claim == flow.LANDER)
end
test_verdict_and_done_do_not_implicitly_release()

local function test_repeated_claim_by_same_reviewer_is_an_overlap()
  local s, id, p = awaiting_review("review-idempotent")
  assert(flow.claim(s, id, flow.REVIEWER, p) == 0)
  local before = check.must(store.load(s, id))
  assert(flow.claim(s, id, flow.REVIEWER, p) ~= 0)
  local after = check.must(store.load(s, id))
  assert(after.claim == before.claim and after.claim_base == before.claim_base)
end
test_repeated_claim_by_same_reviewer_is_an_overlap()
