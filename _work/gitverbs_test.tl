#!/usr/bin/env cosmic
-- V3 claim lifecycle at the command adapter boundary. Claims are
-- independent item-ref CAS operations: there is no board-wide WIP counter,
-- no implicit transport and no provider authentication.

local check = require("cosmic.check")
local claimsession = require("_work.claimsession")
local fixture = require("_work.fixture")
local gate = require("_work.gitgate")
local gitclaim = require("_work.gitclaim")
local claimcli = require("_work.gitclaim_cli")
local item = require("_work.item")
local store = require("_work.store")

local CALLER_A < const > = "0123456789abcdef0123456789abcdef"
local CALLER_B < const > = "fedcba9876543210fedcba9876543210"

local function test_session_new_prints_one_opaque_identity()
  local old_print, seen = _G.print, ""
  _G.print = function(value: any) seen = tostring(value) end
  local code = claimcli.cmd_session("new")
  _G.print = old_print
  assert(code == 0 and claimsession.is_id(seen),
    "session new prints only one usable opaque identity: " .. seen)
end

local function test_local_claim_is_confirmed_and_idempotent()
  local s = fixture.init_state_repo("v3-claim-local")
  local _parent, id = fixture.root_with_leaf(s)
  assert(claimcli.cmd_claim(s, {id}, "take", CALLER_A, "origin", "",
      false, "", false) == 0)
  local first = check.must(store.load(s, id))
  assert(first.claim == CALLER_A and first.claim_base ~= "")
  local state = check.must(gitclaim.read_state(s.root, s.leased_sha[id],
      first.claim, first.claim_base))
  local root, deadline = state.root, state.expires_at
  assert(claimcli.cmd_claim(s, {id}, "take", CALLER_A, "origin", "",
      false, "", false) == 0)
  local again = check.must(store.load(s, id))
  local same = check.must(gitclaim.read_state(s.root, s.leased_sha[id],
      again.claim, again.claim_base))
  assert(same.root == root and same.expires_at == deadline,
    "repeated acquisition is success but never an implicit renewal")
end

local function test_batch_has_no_global_wip_gate_and_keeps_partial_success()
  local s = fixture.init_state_repo("v3-claim-batch")
  local ids: {string} = {}
  for n = 1, 12 do
    ids[#ids + 1] = fixture.file_item(s, ("independent item %d"):format(n), "")
  end
  ids[#ids + 1] = ("z"):rep(27)
  assert(claimcli.cmd_claim(s, ids, "take", CALLER_A, "origin", "",
      false, "", false) == 0,
    "one bad member does not roll back the independently claimable subset")
  local claimed = 0
  for _, it in ipairs(check.must(store.list(s))) do
    if it.claim == CALLER_A then claimed = claimed + 1 end
  end
  assert(claimed == 12,
    "WIP is caller-local policy, not a global board coordination primitive")
end

local function test_foreign_claim_needs_an_audited_force_takeover()
  local s = fixture.init_state_repo("v3-claim-force")
  local _parent, id = fixture.root_with_leaf(s)
  assert(claimcli.cmd_claim(s, {id}, "take", CALLER_A, "origin", "",
      false, "", false) == 0)
  assert(claimcli.cmd_claim(s, {id}, "take", CALLER_B, "origin", "",
      false, "", false) ~= 0)
  assert(check.must(store.load(s, id)).claim == CALLER_A)
  assert(claimcli.cmd_claim(s, {id}, "take", CALLER_B, "origin", "",
      true, "", false) ~= 0, "bare force is not auditable")
  assert(claimcli.cmd_claim(s, {id}, "take", CALLER_B, "origin", "",
      true, "the original caller is gone", false) == 0)
  assert(check.must(store.load(s, id)).claim == CALLER_B)
end

local function test_drop_releases_only_the_claim_and_preserves_workflow_facts()
  local s = fixture.init_state_repo("v3-claim-drop")
  local _parent, id = fixture.root_with_leaf(s)
  assert(claimcli.cmd_claim(s, {id}, "take", CALLER_A, "origin", "",
      false, "", false) == 0)
  local it = check.must(store.load(s, id))
  it.handover_head = it.claim_base
  it.external_url = "https://example.test/change/1"
  assert(item.record_involvement(it.builders, CALLER_A))
  local saved, err = gate.commit_and_publish(s, it, nil,
    "fixture: commit-only handover", "take", nil, CALLER_A)
  assert(saved, err)
  assert(claimcli.cmd_claim(s, {id}, "drop", CALLER_A, "origin", "",
      false, "finished this offline pass", false) == 0)
  local dropped = check.must(store.load(s, id))
  assert(dropped.claim == "", "drop releases the lease")
  assert(dropped.handover_head == it.claim_base
    and dropped.external_url == "https://example.test/change/1"
    and #dropped.builders == 1,
    "drop does not erase commit evidence, navigation, or involvement")
end
