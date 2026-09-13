#!/usr/bin/env cosmic
-- Frozen connector execution must stay bound to one immutable plan, and the
-- claim deadline must be checked again at the final publication call.
local check = require("cosmic.check")
local fs = require("cosmic.fs")
local calls = require("_work.singlehead_calls")
local plans = require("_work.singlehead_plan")

local SHA < const > = "0123456789012345678901234567890123456789"
local DEADLINE < const > = 2000007200

local function ready(): calls.Plan
  local plan: calls.Plan = {
    plan_format = calls.PLAN_FORMAT, status = "ready",
    expected_head = SHA, head = "", repository = "example/board",
    branch = "envelope-poc", transaction = "frozen-transaction",
    transaction_sha = SHA, receipt_digest = string.rep("a", 64),
    source = {}, publish_by = DEADLINE, base_tree_sha = SHA,
    tree_elements = {{path = "gitboard/state.literal", mode = "100644",
        otype = "blob", content = "{}\n"}},
    message = "gitboard envelope frozen-transaction", calls = {},
  }
  plan.calls = check.must(calls.render(plan))
  return plan
end

local function test_deadline_is_rechecked_only_at_the_final_call()
  local plan = ready()
  local first, ferr = calls.connector_call(plan, 1, DEADLINE)
  assert(first ~= nil and first.tool == "github_create_tree", ferr)
  local final, final_err = calls.connector_call(plan, #plan.calls, DEADLINE)
  assert(final == nil and final_err:find("expired", 1, true), final_err)
  final, final_err = calls.connector_call(plan, #plan.calls, DEADLINE - 1)
  assert(final ~= nil and final.tool == "github_update_ref", final_err)
end

local function test_final_publication_call_is_nonforced()
  local plan = ready()
  local final, err = calls.connector_call(plan, #plan.calls, DEADLINE - 1)
  assert(final ~= nil and final.tool == "github_update_ref", err)
  assert(final.arguments.force == false,
    "the frozen publication call must preserve non-forced race semantics")
end

local function test_calls_cannot_be_retargeted_or_mutate_the_plan()
  local plan = ready()
  local wrong, rerr = calls.connector_calls(plan, "other/board", plan.branch)
  assert(wrong == nil and rerr:find("repository differs", 1, true), rerr)
  wrong, rerr = calls.connector_calls(plan, plan.repository, "other-envelope")
  assert(wrong == nil and rerr:find("branch differs", 1, true), rerr)
  local copied = check.must(calls.connector_calls(plan))
  copied[1].arguments.repository_full_name = "other/board"
  local again = check.must(calls.connector_calls(plan))
  assert(again[1].arguments.repository_full_name == plan.repository,
    "returned connector calls must not mutate the sealed plan")
  plan.calls[#plan.calls].arguments.branch_name = "other-envelope"
  local valid, verr = calls.validate(plan)
  assert(not valid and verr:find("malformed", 1, true), verr)
end

local function test_saved_plan_is_create_once_and_detached_from_mutation()
  local plan = ready()
  local path = fs.join(assert(os.getenv("TEST_TMPDIR")), "frozen-plan.literal")
  local saved, serr = plans.save(path, plan)
  assert(saved, serr)
  local sealed = check.must(fs.read(path))
  assert(sealed:sub(1, 7) == "return "
    and sealed:find("gitboard-single-head-plan-v2", 1, true),
    "saved plans must use the non-executable v2 literal wire format")
  plan.transaction_sha = string.rep("b", 40)
  plan.tree_elements[1].content = "mutated after save\n"
  local loaded, lerr = plans.load(path)
  assert(loaded ~= nil, lerr)
  assert(loaded.transaction_sha == SHA
    and loaded.tree_elements[1].content == "{}\n",
    "saved plan must retain the exact immutable transaction and tree")
  saved, serr = plans.save(path, loaded)
  assert(not saved and serr:find("already exists", 1, true), serr)
end
