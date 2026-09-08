#!/usr/bin/env cosmic
-- Pure lease boundary tests: exact expiry, skew, idempotency, audited force,
-- whole-item freezing, manual renewal, and stable per-attempt branches.
local claim = require("_work.claim")
local claimsession = require("_work.claimsession")

local NOW < const > = 2000000000

local function state(holder?: string, touched?: integer): claim.State
  local at = touched or NOW
  return {holder = holder or "caller-a", root = ("a"):rep(40),
    control = ("b"):rep(40), acquired_at = NOW, renewed_at = at,
    expires_at = at + claim.LEASE_S, product_base = ("c"):rep(40)}
end

local function test_exact_two_hour_expiry_and_future_skew()
  local st = state()
  assert(claim.status(st, NOW + claim.LEASE_S - 1) == "active")
  assert(claim.status(st, NOW + claim.LEASE_S) == "expired")
  assert(claim.status(state("caller-a", NOW + claim.FUTURE_SKEW_S), NOW) == "active")
  assert(claim.status(state("caller-a", NOW + claim.FUTURE_SKEW_S + 1), NOW) == "future")
end

local function test_take_is_idempotent_for_owner_without_renewal()
  local st = state()
  local refusal, owned = claim.take_refusal(st, "caller-a", NOW + 30, false, "")
  assert(refusal == nil and owned, tostring(refusal))
  assert(st.expires_at == NOW + claim.LEASE_S, "take did not renew")
end

local function test_active_claim_freezes_item_except_audited_force()
  local st = state()
  assert(claim.mutation_refusal(st, "caller-b", NOW, false, "") ~= nil)
  assert(claim.mutation_refusal(st, "caller-b", NOW, true, "") ~= nil)
  assert(claim.mutation_refusal(st, "caller-b", NOW, true, "runner died") == nil)
  assert(claim.mutation_refusal(st, "caller-a", NOW, false, "") == nil)
  assert(claim.mutation_refusal(st, "caller-b", NOW + claim.LEASE_S,
      false, "") == nil, "expiry unfreezes without a mutation")
end

local function test_only_live_owner_renews_but_expired_owner_may_drop()
  local st = state()
  assert(claim.renew_refusal(st, "caller-a", NOW + 1) == nil)
  assert(claim.renew_refusal(st, "caller-b", NOW + 1) ~= nil)
  assert(claim.renew_refusal(st, "caller-a", NOW + claim.LEASE_S) ~= nil)
  assert(claim.drop_refusal(st, "caller-a", NOW + claim.LEASE_S,
      false, "") == nil, "expired holder may still race a drop CAS")
end

local function test_force_take_and_drop_need_a_reason()
  local st = state()
  local bad = claim.take_refusal(st, "caller-b", NOW, true, "")
  assert(bad ~= nil)
  local ok = claim.take_refusal(st, "caller-b", NOW, true, "stuck")
  assert(ok == nil)
  assert(claim.drop_refusal(st, "caller-b", NOW, true, "") ~= nil)
  assert(claim.drop_refusal(st, "caller-b", NOW, true, "stuck") == nil)
end

local function test_branch_uses_item_handle_and_initial_claim()
  assert(claim.branch("0123456789abcdefghijklmnopq", ("a"):rep(40))
    == "work/jklmnopq/aaaaaaaaaaaa")
end

local function test_sessions_are_minted_and_distinct()
  local a, b = claimsession.mint(), claimsession.mint()
  assert(claimsession.is_id(a) and claimsession.is_id(b) and a ~= b)
end
