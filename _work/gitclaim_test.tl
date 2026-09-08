#!/usr/bin/env cosmic
-- Focused policy and recovery tests for `_work.gitclaim`. Representation,
-- publication races, and lifecycle invariants live in
-- `gitclaim_batch_object_test.tl`.
local check = require("cosmic.check")
local claim = require("_work.claim")
local claimbatch = require("_work.claimbatch")
local fixture = require("_work.fixture")
local gitclaim = require("_work.gitclaim")
local prepared = require("_work.prepared")
local refs = require("_work.refs")
local store = require("_work.store")

local NOW < const > = 1900000000
local BASE < const > = "0123456789012345678901234567890123456789"
local ALICE < const > = "0123456789abcdef0123456789abcdef"
local BOB < const > = "abcdef0123456789abcdef0123456789"

local function request(s: store.Store, id: string, batch: string,
    caller?: string, action?: gitclaim.Action,
    now?: integer): gitclaim.Request
  return {root = s.root, id = id, source_ref = gitclaim.target_item_ref(id),
    target_ref = gitclaim.target_item_ref(id), remote = "origin",
    batch = batch, caller = caller or ALICE, action = action or "take",
    product_base = BASE, force = false, why = "", now = now or NOW}
end

local function prepare_one(s: store.Store, id: string, batch: string,
    caller?: string, action?: gitclaim.Action,
    now?: integer): gitclaim.Prepared
  local result = gitclaim.prepare_batch(
    {request(s, id, batch, caller, action, now)})
  assert(next(result.refused) == nil, result.refused[id] or result.refused.batch)
  return check.must(result.prepared)
end

local function test_policy_refusal_leaves_no_prepared_transaction()
  local s = fixture.init_state_repo("claim-policy-refusal")
  local id = fixture.file_item(s, "valid member", "")
  local missing = "does_not_exist"
  local result = gitclaim.prepare_batch({request(s, id, "refused"),
      request(s, missing, "refused")})
  assert(result.prepared == nil and result.refused[missing] ~= nil)
  assert(#check.must(prepared.list(s.root)) == 0,
    "a policy-invalid member must leave no publishable subset")
end

local function test_duplicate_member_rejects_the_whole_set()
  local s = fixture.init_state_repo("claim-duplicate")
  local id = fixture.file_item(s, "duplicate member", "")
  local req = request(s, id, "duplicate")
  local result = gitclaim.prepare_batch({req, req})
  assert(result.prepared == nil)
  assert((result.refused[id] or ""):find("more than once", 1, true))
end

local function test_active_foreign_claim_refuses_even_when_force_is_requested()
  local s = fixture.init_state_repo("claim-force")
  local id = fixture.file_item(s, "force target", "")
  local first = prepare_one(s, id, "first")
  assert(prepared.promote_local(s.root, first.transaction))

  local denied = gitclaim.prepare_batch(
    {request(s, id, "denied", BOB, "take", NOW + 1)})
  assert(denied.prepared == nil)
  assert((denied.refused[id] or ""):find("claimed by", 1, true))

  local forced_req = request(s, id, "forced", BOB, "take", NOW + 1)
  forced_req.force = true
  forced_req.why = "the original caller is gone"
  local forced_result = gitclaim.prepare_batch({forced_req})
  assert(forced_result.prepared == nil)
  assert((forced_result.refused[id] or ""):find("claimed by", 1, true),
    "an overlap must reject the whole acquire regardless of legacy force fields")
end

local function test_prepared_batch_is_rediscovered_from_one_receipt()
  local s = fixture.init_state_repo("claim-recovery")
  local a = fixture.file_item(s, "recover a", "")
  local b = fixture.file_item(s, "recover b", "")
  local result = gitclaim.prepare_batch({request(s, a, "recover"),
      request(s, b, "recover")})
  local original = check.must(result.prepared)
  local recovered = check.must(gitclaim.list_prepared(s.root, "origin"))
  assert(#recovered == 1 and recovered[1].id == original.id)
  assert(recovered[1].batch.commit == original.batch.commit)
  assert(recovered[1].transaction.manifest == original.transaction.manifest)
  assert(#recovered[1].members == 2 and recovered[1].deadline == original.deadline)
end

local function test_completed_item_keeps_its_existing_ref_namespace()
  local s = fixture.init_state_repo("claim-ended-namespace")
  local id = fixture.file_item(s, "legacy ended item", "")
  local item_ref = gitclaim.target_item_ref(id)
  local ended_ref = gitclaim.target_item_ref(id, true)
  local tip = check.must(refs.read_ref(s.root, item_ref))
  assert(refs.update_ref(s.root, ended_ref, tip, refs.ZERO_SHA))
  assert(refs.update_ref(s.root, item_ref, refs.ZERO_SHA, tip))
  local req = request(s, id, "ended")
  req.source_ref, req.target_ref = ended_ref, ended_ref
  local result = gitclaim.prepare_batch({req})
  local p = check.must(result.prepared)
  assert(p.members[1].target_ref == ended_ref)
  local fact = check.must(claimbatch.read_fact(s.root, p.batch.commit, id))
  assert(fact.holder == ALICE and fact.expires_at == NOW + claim.LEASE_S)
end
