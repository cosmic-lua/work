#!/usr/bin/env cosmic
-- Shared claim-batch lifecycle at the command adapter boundary. Item refs are
-- the overlap fences; there is no global WIP gate or provider authentication.

local check = require("cosmic.check")
local claimsession = require("_work.claimsession")
local fixture = require("_work.fixture")
local gate = require("_work.gitgate")
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

local function test_local_claim_is_confirmed_and_repeat_overlaps()
  local s = fixture.init_state_repo("v3-claim-local")
  local _parent, id = fixture.root_with_leaf(s)
  assert(claimcli.cmd_claim(s, {id}, "take", CALLER_A, "origin", "",
      false, "", false) == 0)
  local first = check.must(store.load(s, id))
  assert(first.claim == CALLER_A and first.claim_base ~= "")
  assert(claimcli.cmd_claim(s, {id}, "take", CALLER_A, "origin", "",
      false, "", false) ~= 0,
    "every live overlap rejects the whole acquisition, including same caller")
end

local function test_batch_has_no_global_wip_gate_but_is_all_or_nothing()
  local s = fixture.init_state_repo("v3-claim-batch")
  local ids: {string} = {}
  for n = 1, 12 do
    ids[#ids + 1] = fixture.file_item(s, ("independent item %d"):format(n), "")
  end
  ids[#ids + 1] = ("z"):rep(27)
  assert(claimcli.cmd_claim(s, ids, "take", CALLER_A, "origin", "",
      false, "", false) ~= 0,
    "one bad member rejects the requested set")
  local claimed = 0
  for _, it in ipairs(check.must(store.list(s))) do
    if it.claim == CALLER_A then claimed = claimed + 1 end
  end
  assert(claimed == 0, "an invalid member cannot leave a claimed subset")
end

local function test_live_claim_cannot_be_forced_over()
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
      true, "the original caller is gone", false) ~= 0,
    "force cannot bypass a live overlap")
  assert(check.must(store.load(s, id)).claim == CALLER_A)
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
