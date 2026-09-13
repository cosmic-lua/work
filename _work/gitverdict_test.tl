#!/usr/bin/env cosmic
-- Commit-only verdict policy: the reviewer holds the whole-item claim and
-- judges exactly the locally inspectable commit handed over by the builder.
local check = require("cosmic.check")
local flow = require("_work.commit_flow_fixture")
local store = require("_work.store")
local verdict = require("_work.gitverdict")

local function review_ready(name: string): store.Store, string,
  flow.Product
  local s, id, p = flow.fresh(name)
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  assert(flow.handover(s, id, flow.BUILDER, p, p.head) == 0)
  assert(flow.claim(s, id, flow.BUILDER, p, "drop") == 0)
  assert(flow.claim(s, id, flow.REVIEWER, p) == 0)
  return s, id, p
end

local function test_accept_records_only_the_handed_over_commit()
  local s, id, p = review_ready("verdict-accept")
  assert(verdict.cmd_verdict_commit(s, id, "accept", p.head:sub(1, 12),
      flow.REVIEWER, false, "", p.root) == 0)
  local it = check.must(store.load(s, id))
  assert(it.verdict == "accept" and it.verdict_head == p.head)
  assert(it.handover_head == p.head)
  assert(it.claim == flow.REVIEWER, "a verdict never releases a claim")
end
test_accept_records_only_the_handed_over_commit()

local function test_verdict_refuses_a_commit_other_than_the_handover()
  local s, id, p = review_ready("verdict-moved")
  assert(verdict.cmd_verdict_commit(s, id, "accept", p.next_head,
      flow.REVIEWER, false, "", p.root) ~= 0)
  local it = check.must(store.load(s, id))
  assert((it.verdict or "") == "" and (it.verdict_head or "") == "")
end
test_verdict_refuses_a_commit_other_than_the_handover()

local function test_the_claim_holder_is_the_only_reviewer_who_can_write()
  local s, id, p = review_ready("verdict-holder")
  assert(verdict.cmd_verdict_commit(s, id, "accept", p.head,
      flow.OTHER, false, "", p.root) ~= 0)
  assert((check.must(store.load(s, id)).verdict or "") == "")
end
test_the_claim_holder_is_the_only_reviewer_who_can_write()

local function test_distance_requires_an_audited_force()
  local s, id, p = flow.fresh("verdict-distance")
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  assert(flow.handover(s, id, flow.BUILDER, p, p.head) == 0)
  assert(verdict.cmd_verdict_commit(s, id, "accept", p.head,
      flow.BUILDER, false, "", p.root) ~= 0)
  assert(verdict.cmd_verdict_commit(s, id, "accept", p.head,
      flow.BUILDER, true, "", p.root) ~= 0,
    "bare --force has no audit trail")
  assert(verdict.cmd_verdict_commit(s, id, "accept", p.head,
      flow.BUILDER, true, "emergency self-review", p.root) == 0)
end
test_distance_requires_an_audited_force()

local function test_request_changes_alias_and_repeated_judgement()
  local s, id, p = review_ready("verdict-alias")
  assert(verdict.cmd_verdict_commit(s, id, "request-changes", p.head,
      flow.REVIEWER, false, "", p.root) == 0)
  local it = check.must(store.load(s, id))
  assert(it.verdict == "request changes" and it.verdict_head == p.head)
  assert(verdict.cmd_verdict_commit(s, id, "request changes", p.head,
      flow.REVIEWER, false, "", p.root) ~= 0,
    "the same commit/verdict pair is not recorded twice")
end
test_request_changes_alias_and_repeated_judgement()

local function test_reject_clears_the_handover_but_not_the_claim()
  local s, id, p = review_ready("verdict-reject")
  assert(verdict.cmd_verdict_commit(s, id, "reject", p.head,
      flow.REVIEWER, false, "", p.root) == 0)
  local it = check.must(store.load(s, id))
  assert((it.verdict or "") == "" and (it.handover_head or "") == "")
  assert((it.external_url or "") == "" and it.claim == flow.REVIEWER)
  assert(it.verdict_head == p.head,
    "the rejected commit remains the durable verdict evidence")
end
test_reject_clears_the_handover_but_not_the_claim()

local function test_legacy_pr_verdict_is_read_only_refused()
  local s, id, p = review_ready("verdict-legacy")
  assert(verdict.cmd_verdict(s, id, "accept", 7, p.head,
      flow.REVIEWER) ~= 0)
  assert((check.must(store.load(s, id)).verdict or "") == "")
end
test_legacy_pr_verdict_is_read_only_refused()
