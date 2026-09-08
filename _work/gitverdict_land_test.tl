#!/usr/bin/env cosmic
-- Completion proves a locally present landed commit. Provider state, checks,
-- credentials, and pull-request objects are outside the board data model.
local check = require("cosmic.check")
local flow = require("_work.commit_flow_fixture")
local done = require("_work.gitdone")
local store = require("_work.store")
local verdict = require("_work.gitverdict")

local function accepted(name: string): store.Store, string, flow.Product
  local s, id, p = flow.fresh(name)
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  assert(flow.handover(s, id, flow.BUILDER, p, p.next_head) == 0)
  assert(flow.claim(s, id, flow.BUILDER, p, "drop") == 0)
  assert(flow.claim(s, id, flow.REVIEWER, p) == 0)
  assert(verdict.cmd_verdict_commit(s, id, "accept", p.next_head,
      flow.REVIEWER, false, "", p.root) == 0)
  assert(flow.claim(s, id, flow.REVIEWER, p, "drop") == 0)
  assert(flow.claim(s, id, flow.LANDER, p) == 0)
  return s, id, p
end

local function test_history_preserving_landing_completes()
  local s, id, p = accepted("land-ancestry")
  assert(done.cmd_done(s, id, "completed", false, "", "", p.next_head,
      p.root, flow.LANDER) == 0)
  local it = check.must(store.load(s, id))
  assert(it.resolution == "completed" and it.landed_head == p.next_head)
  assert(it.verdict_head == p.next_head and it.claim == flow.LANDER)
end
test_history_preserving_landing_completes()

local function test_exact_squash_landing_completes()
  local s, id, p = accepted("land-squash")
  assert(done.cmd_done(s, id, "completed", false, "", "", p.squash,
      p.root, flow.LANDER) == 0)
  local it = check.must(store.load(s, id))
  assert(it.resolution == "completed" and it.landed_head == p.squash)
end
test_exact_squash_landing_completes()

local function test_different_content_is_not_a_landing()
  local s, id, p = accepted("land-mismatch")
  assert(done.cmd_done(s, id, "completed", false, "", "", p.mismatch,
      p.root, flow.LANDER) ~= 0)
  local it = check.must(store.load(s, id))
  assert((it.resolution or "") == "" and (it.landed_head or "") == "")
  assert(it.claim == flow.LANDER)
end
test_different_content_is_not_a_landing()

local function test_accepted_work_requires_a_landed_commit()
  local s, id, p = accepted("land-required")
  assert(done.cmd_done(s, id, "completed", false, "", "", "",
      p.root, flow.LANDER) ~= 0)
  assert((check.must(store.load(s, id)).resolution or "") == "")
end
test_accepted_work_requires_a_landed_commit()

local function test_only_the_landing_claim_holder_can_complete()
  local s, id, p = accepted("land-holder")
  assert(done.cmd_done(s, id, "completed", false, "", "", p.squash,
      p.root, flow.OTHER) ~= 0)
  assert((check.must(store.load(s, id)).resolution or "") == "")
end
test_only_the_landing_claim_holder_can_complete()

local function test_landed_is_only_for_completed_accepted_work()
  local s, id, p = accepted("land-reason")
  assert(done.cmd_done(s, id, "not-planned", false, "", "", p.squash,
      p.root, flow.LANDER) ~= 0)
  assert((check.must(store.load(s, id)).resolution or "") == "")
end
test_landed_is_only_for_completed_accepted_work()
