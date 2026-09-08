#!/usr/bin/env cosmic
-- Commit handover and rework are board-local transitions. The caller fetches
-- product history first; Gitboard records a commit id and optional link only.
local check = require("cosmic.check")
local flow = require("_work.commit_flow_fixture")
local store = require("_work.store")
local verdict = require("_work.gitverdict")

local function test_handover_records_full_commit_url_and_builder()
  local s, id, p = flow.fresh("handover-record")
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  assert(flow.handover(s, id, flow.BUILDER, p, p.head:sub(1, 10),
      "https://example.test/change/7") == 0)
  local it = check.must(store.load(s, id))
  assert(it.handover_head == p.head)
  assert(it.external_url == "https://example.test/change/7")
  assert(#it.builders == 1 and it.builders[1] == flow.BUILDER,
    "involvement begins at handover, not claim acquisition")
  assert(it.claim == flow.BUILDER, "handover never releases the claim")
  assert((it.pr or 0) == 0 and (it.result or "") == "")
end
test_handover_records_full_commit_url_and_builder()

local function test_only_the_claim_holder_can_handover()
  local s, id, p = flow.fresh("handover-holder")
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  assert(flow.handover(s, id, flow.OTHER, p, p.head) ~= 0)
  assert((check.must(store.load(s, id)).handover_head or "") == "")
end
test_only_the_claim_holder_can_handover()

local function test_handover_must_descend_the_claim_base()
  local s, id, p = flow.fresh("handover-lineage")
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  assert(flow.handover(s, id, flow.BUILDER, p, p.unrelated) ~= 0)
  assert(flow.handover(s, id, flow.BUILDER, p,
      "1234567890abcdef") ~= 0)
  assert((check.must(store.load(s, id)).handover_head or "") == "")
end
test_handover_must_descend_the_claim_base()

local function test_handover_url_is_non_authoritative_but_well_formed()
  local s, id, p = flow.fresh("handover-url")
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  assert(flow.handover(s, id, flow.BUILDER, p, p.head,
      "file:///tmp/not-navigation") ~= 0)
  assert((check.must(store.load(s, id)).handover_head or "") == "")
  assert(flow.handover(s, id, flow.BUILDER, p, p.head, "") == 0)
  assert((check.must(store.load(s, id)).external_url or "") == "")
end
test_handover_url_is_non_authoritative_but_well_formed()

local function test_same_handover_is_idempotent()
  local s, id, p = flow.fresh("handover-idempotent")
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  assert(flow.handover(s, id, flow.BUILDER, p, p.head) == 0)
  local before = check.must(store.load(s, id))
  assert(flow.handover(s, id, flow.BUILDER, p, p.head) == 0)
  local after = check.must(store.load(s, id))
  assert(after.handover_head == before.handover_head)
  assert(#after.builders == 1, "idempotence does not duplicate involvement")
end
test_same_handover_is_idempotent()

local function test_rework_requires_explicit_claim_transfers()
  local s, id, p = flow.fresh("handover-rework")
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  assert(flow.handover(s, id, flow.BUILDER, p, p.head) == 0)
  assert(flow.claim(s, id, flow.BUILDER, p, "drop") == 0)
  assert(flow.claim(s, id, flow.REVIEWER, p) == 0)
  assert(verdict.cmd_verdict_commit(s, id, "request changes", p.head,
      flow.REVIEWER, false, "", p.root) == 0)
  assert(check.must(store.load(s, id)).claim == flow.REVIEWER)

  assert(flow.claim(s, id, flow.REVIEWER, p, "drop") == 0)
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  assert(flow.handover(s, id, flow.BUILDER, p, p.next_head) == 0)
  local reworked = check.must(store.load(s, id))
  assert(reworked.handover_head == p.next_head)
  assert((reworked.verdict or "") == "",
    "a fresh handover answers request changes")
  assert((reworked.verdict_head or "") == "")
  assert(reworked.claim == flow.BUILDER)
  assert(#reworked.builders == 1 and reworked.builders[1] == flow.BUILDER)
end
test_rework_requires_explicit_claim_transfers()
