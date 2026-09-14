#!/usr/bin/env cosmic
-- Whole-set claim policy and recovery on canonical format-6 claim files.
local check = require("cosmic.check")
local fixture = require("_work.fixture")
local refs = require("_work.refs")
local stateclaim = require("_work.stateclaim")
local statepublish = require("_work.statepublish")
local staging = require("_work.statestaging")
local statewrite = require("_work.statewrite")
local store = require("_work.store")

local NOW < const > = os.time()
local BASE < const > = "0123456789012345678901234567890123456789"
local ALICE < const > = "0123456789abcdef0123456789abcdef"
local BOB < const > = "abcdef0123456789abcdef0123456789"

local function requests(ids: {string}): {stateclaim.Request}
  local out: {stateclaim.Request} = {}
  for _, id in ipairs(ids) do
    out[#out + 1] = {id = id, product_base = BASE}
  end
  return out
end

local function prepare(s: store.Store, ids: {string}, action?: stateclaim.Action,
    caller?: string, now?: integer, force?: boolean,
    why?: string): stateclaim.Result
  return stateclaim.prepare(s.root, s.state_head, requests(ids),
    action or "take", caller or ALICE, now or NOW, force or false, why or "")
end

local function stage(s: store.Store, result: stateclaim.Result)
  assert(next(result.refused) == nil, result.refused.batch)
  for _, dependency in ipairs(result.dependencies) do
    s.state_paths[dependency.path] = dependency.id
    s.state_reads[dependency.path] = dependency.id
  end
  assert(statewrite.transition(s, result.changes, "claim fixture",
      result.publish_by))
end

local function test_policy_refusal_leaves_no_prepared_transaction()
  local s = fixture.init_state_repo("claim-policy-refusal")
  local id = fixture.file_item(s, "valid member", "")
  local result = prepare(s, {id, "does_not_exist"})
  assert(result.refused.does_not_exist ~= nil)
  assert(#result.changes == 0 and #result.members == 0)
  assert(#check.must(staging.list(s.root)) == 0,
    "a policy-invalid member must leave no publishable subset")
end

local function test_duplicate_member_rejects_the_whole_set()
  local s = fixture.init_state_repo("claim-duplicate")
  local id = fixture.file_item(s, "duplicate member", "")
  local result = prepare(s, {id, id})
  assert((result.refused[id] or ""):find("more than once", 1, true))
  assert(#result.changes == 0 and #result.members == 0)
end

local function test_foreign_overlap_cannot_be_forced()
  local s = fixture.init_state_repo("claim-force")
  local id = fixture.file_item(s, "force target", "")
  stage(s, prepare(s, {id}))
  assert(statepublish.publish(s))

  local denied = prepare(s, {id}, "take", BOB, NOW + 1)
  assert(denied.refused[id] ~= nil and #denied.changes == 0)
  local unsafe = prepare(s, {id}, "take", BOB, NOW + 1, true)
  assert(unsafe.refused[id] ~= nil and #unsafe.changes == 0)
  local forced = prepare(s, {id}, "take", BOB, NOW + 1, true,
    "the original session is gone")
  assert(forced.refused[id] ~= nil and #forced.members == 0 and #forced.changes == 0)
end

local function test_one_native_receipt_recovers_the_whole_set()
  local s = fixture.init_state_repo("claim-recovery")
  local a = fixture.file_item(s, "recover a", "")
  local b = fixture.file_item(s, "recover b", "")
  local result = prepare(s, {a, b})
  stage(s, result)
  local recovered = check.must(staging.list(s.root, "prepared"))
  assert(#recovered == 1 and #recovered[1].transitions == 1)
  assert(recovered[1].transitions[1].publish_by == result.publish_by)
  assert(recovered[1].tip == s.state_head)
  assert(check.must(refs.read_ref(s.root, recovered[1].ref))
    == recovered[1].sha)
end
