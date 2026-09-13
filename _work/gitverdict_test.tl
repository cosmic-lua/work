#!/usr/bin/env cosmic
-- Commit-only verdict policy: the reviewer holds the whole-item claim and
-- judges exactly the locally inspectable commit handed over by the builder.
local check = require("cosmic.check")
local commit_evidence = require("_work.commit_evidence")
local flow = require("_work.commit_flow_fixture")
local gittake = require("_work.gittake")
local item = require("_work.item")
local store = require("_work.store")
local storewrite = require("_work.storewrite")
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

-- A research handover: the builder hands the board state over with
-- `take --result`, which records the item ref's tip as it stood — a
-- board commit, not a product one — then drops, and the reviewer claims.
-- `review_ready` with the deliverable the other way round.
local function research_ready(name: string): store.Store, string,
  flow.Product, string
  local s, id, p = flow.fresh(name)
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  check.must(store.list(s))
  local it = check.must(store.load(s, id))
  assert(item.record_involvement(it.builders, flow.BUILDER))
  assert(gittake.take_result(s, it, flow.BUILDER, 0) == 0)
  assert(flow.claim(s, id, flow.BUILDER, p, "drop") == 0)
  assert(flow.claim(s, id, flow.REVIEWER, p) == 0)
  local result = check.must(store.load(s, id)).result or ""
  assert(#result == 40, "the handover recorded a board commit")
  return s, id, p, result
end

local function test_accept_records_a_research_handovers_board_commit()
  local s, id, _p, result = research_ready("verdict-research-accept")
  -- No `--repo-dir` and no repository mapping: a board commit is judged
  -- in the board checkout, and the product checkout is never resolved.
  assert(verdict.cmd_verdict_commit(s, id, "accept", result,
      flow.REVIEWER, false, "", "") == 0)
  local it = check.must(store.load(s, id))
  assert(it.verdict == "accept" and it.verdict_head == result)
  assert(it.result == result and (it.handover_head or "") == "")
  assert(it.claim == flow.REVIEWER, "a verdict never releases a claim")
end
test_accept_records_a_research_handovers_board_commit()

local function test_request_changes_on_a_research_head()
  local s, id, p, result = research_ready("verdict-research-rework")
  assert(verdict.cmd_verdict_commit(s, id, "request-changes", result,
      flow.REVIEWER, false, "", p.root) == 0)
  local it = check.must(store.load(s, id))
  assert(it.verdict == "request changes" and it.verdict_head == result)
  assert(it.result == result, "a send-back leaves the handover standing")
end
test_request_changes_on_a_research_head()

local function test_a_head_that_is_neither_the_handover_nor_the_result()
  local s, id, p, result = research_ready("verdict-research-neither")
  assert(verdict.cmd_verdict_commit(s, id, "accept", p.head,
      flow.REVIEWER, false, "", p.root) ~= 0,
    "a product commit is not the head of a research handover")
  assert(verdict.cmd_verdict_commit(s, id, "accept", result:sub(1, 12),
      flow.REVIEWER, false, "", p.root) ~= 0,
    "a research head is named exactly, never by prefix")
  local it = check.must(store.load(s, id))
  assert((it.verdict or "") == "" and (it.verdict_head or "") == "")
end
test_a_head_that_is_neither_the_handover_nor_the_result()

local function test_a_result_off_the_items_own_ref_is_refused()
  local s, id, p = research_ready("verdict-research-off-ref")
  -- Another item's tip: a commit this board resolves, in no way part of
  -- this item's ref history — the shape a mis-recorded `result` takes.
  local all = check.must(store.list(s))
  local elsewhere = ""
  for _, other in ipairs(all) do
    if other.id ~= id and (s.leased_sha[other.id] or "") ~= "" then
      elsewhere = s.leased_sha[other.id]
    end
  end
  assert(check.must(commit_evidence.commit_id(s.root, elsewhere)) == elsewhere,
    "the fixture found a board commit off this item's ref")
  local it = check.must(store.load(s, id))
  it.result = elsewhere
  assert(storewrite.save(s, it, "point the result off the ref"))
  assert(verdict.cmd_verdict_commit(s, id, "accept", elsewhere,
      flow.REVIEWER, false, "", p.root) ~= 0)
  assert((check.must(store.load(s, id)).verdict or "") == "")
end
test_a_result_off_the_items_own_ref_is_refused()

-- The research counterpart of `reject` above. Clearing `result` is what
-- turns the item mid-flight again: `is_review_or_rework` reads a standing
-- `result` as review, and `take_result`'s unmoved-spec no-op would then
-- swallow the re-handover as "already records this spec's handover".
local function test_reject_on_a_research_head_clears_the_result()
  local s, id, p, result = research_ready("verdict-research-reject")
  assert(verdict.cmd_verdict_commit(s, id, "reject", result,
      flow.REVIEWER, false, "", "") == 0)
  local it = check.must(store.load(s, id))
  assert((it.verdict or "") == "" and (it.result or "") == "",
    "reject clears the research handover")
  assert(it.claim == flow.REVIEWER, "a verdict never releases a claim")
  assert(it.verdict_head == result,
    "the rejected commit remains the durable verdict evidence")
  assert(not item.is_review_or_rework(it), "the item reads as mid-flight")
  -- The re-handover: the reviewer lets go, the builder takes the item
  -- back and hands the board state over again — a new tip, not the
  -- no-op an unmoved spec over a standing `result` would be.
  assert(flow.claim(s, id, flow.REVIEWER, p, "drop") == 0)
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  check.must(store.list(s))
  it = check.must(store.load(s, id))
  assert(gittake.take_result(s, it, flow.BUILDER, 0) == 0)
  local again = check.must(store.load(s, id)).result or ""
  assert(#again == 40 and again ~= result,
    "the next `take --result` records a new tip")
end
test_reject_on_a_research_head_clears_the_result()

-- Both heads recorded: `take_handover` clears `result` but `take_result`
-- leaves `handover_head` standing, so a product handover followed by a
-- research one carries both. The product commit is then the handover,
-- judged in the product checkout `repo_dir` resolves.
local function test_with_both_heads_recorded_the_product_commit_is_judged()
  local s, id, p = flow.fresh("verdict-both-heads")
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  assert(flow.handover(s, id, flow.BUILDER, p, p.head) == 0)
  check.must(store.list(s))
  local it = check.must(store.load(s, id))
  assert(gittake.take_result(s, it, flow.BUILDER, 0) == 0)
  assert(flow.claim(s, id, flow.BUILDER, p, "drop") == 0)
  assert(flow.claim(s, id, flow.REVIEWER, p) == 0)
  it = check.must(store.load(s, id))
  local result = it.result or ""
  assert(#result == 40 and it.handover_head == p.head, "both heads recorded")
  assert(verdict.cmd_verdict_commit(s, id, "accept", result,
      flow.REVIEWER, false, "", p.root) ~= 0,
    "the board commit is not the head once a product commit is handed over")
  assert((check.must(store.load(s, id)).verdict or "") == "")
  assert(verdict.cmd_verdict_commit(s, id, "accept", p.head,
      flow.REVIEWER, false, "", p.root) == 0)
  it = check.must(store.load(s, id))
  assert(it.verdict == "accept" and it.verdict_head == p.head)
  assert(it.handover_head == p.head and it.result == result,
    "the verdict leaves both recorded heads as they were")
end
test_with_both_heads_recorded_the_product_commit_is_judged()
