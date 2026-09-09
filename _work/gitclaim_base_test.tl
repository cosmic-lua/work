#!/usr/bin/env cosmic
-- New acquisitions resolve today's target; lease updates retain their base.
local check = require("cosmic.check")
local claim = require("_work.claim")
local claimbatch = require("_work.claimbatch")
local fixture = require("_work.fixture")
local gitclaim = require("_work.gitclaim")
local gitclaim_cli = require("_work.gitclaim_cli")
local graph = require("_work.gitgraph")
local prepared = require("_work.prepared")
local product_fixture = require("_work.commit_flow_fixture")
local refs = require("_work.refs")
local store = require("_work.store")

local CALLER < const > = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
local BASE < const > = "0123456789012345678901234567890123456789"
local NEXT_BASE < const > = string.rep("a", 40)
local NOW < const > = os.time() - claim.LEASE_S - 10

local function reopen(s: store.Store): store.Store
  assert(store.close(s))
  local opened = check.must(store.open(s.root))
  local _items = check.must(store.list(opened)) -- exercise the durable cache
  return opened
end

local function fact(s: store.Store, id: string): claimbatch.Fact
  local it = check.must(store.load(s, id))
  return check.must(claimbatch.read_fact(s.root, it.claim_batch or "", id))
end

local function cmd_claim(s: store.Store, id: string, action: gitclaim.Action,
    product_root?: string)
  assert(gitclaim_cli.cmd_claim(s, {id}, action, CALLER, "origin",
      product_root or "", false, "", false) == 0)
end

local function test_repaired_target_replaces_released_board_base()
  local s = fixture.init_state_repo("claim-base-repaired")
  local _, id = fixture.root_with_leaf(s)
  local item_tip = check.must(refs.read_ref(s.root, gitclaim.target_item_ref(id)))
  cmd_claim(s, id, "take")
  s = reopen(s)
  assert(fact(s, id).product_base == item_tip,
    "repo-less acquisition records the current item commit")
  cmd_claim(s, id, "drop")
  s = reopen(s)
  assert(fact(s, id).action == "drop" and fact(s, id).product_base == item_tip)

  local product = product_fixture.product("claim-base-repaired")
  assert(product.base ~= item_tip, "product main must differ from board history")
  assert(graph.cmd_set(s, id, nil, "acme/widgets", "main") == 0)
  s = reopen(s)
  local repaired = check.must(store.load(s, id))
  assert(repaired.repo == "acme/widgets" and repaired.base == "main")
  assert(fact(s, id).product_base == item_tip,
    "target repair retains the historical claim fact until acquisition")
  cmd_claim(s, id, "take", product.root)
  s = reopen(s)
  local acquired = fact(s, id)
  assert(acquired.action == "acquire" and acquired.product_base == product.base,
    "fresh acquisition must use product main, not the released board base")
  assert(store.close(s))
end

local function test_repo_less_reacquisition_uses_current_item_commit()
  local s = fixture.init_state_repo("claim-base-board-only")
  local id = fixture.file_item(s, "board-only work", "")
  cmd_claim(s, id, "take")
  cmd_claim(s, id, "drop")
  s = reopen(s)
  local old_base = fact(s, id).product_base
  local current = check.must(refs.read_ref(s.root, gitclaim.target_item_ref(id)))
  assert(current ~= old_base, "claim/drop advances item history")
  cmd_claim(s, id, "take")
  s = reopen(s)
  assert(fact(s, id).product_base == current,
    "repo-less reacquisition uses the item commit resolved for this request")
  assert(store.close(s))
end

local function apply(s: store.Store, id: string, action: gitclaim.Action,
    base: string, now: integer): claimbatch.Row
  local ref = gitclaim.target_item_ref(id)
  local result = gitclaim.prepare_batch({{
        root = s.root, id = id, source_ref = ref, target_ref = ref,
        remote = "origin", batch = action .. "-" .. tostring(now),
        caller = CALLER, action = action, product_base = base,
        force = false, why = "", now = now,
      }})
  assert(result.prepared ~= nil, result.refused[id] or result.refused.batch)
  assert(prepared.promote_local(s.root, result.prepared.transaction))
  return result.prepared.batch.rows[1]
end

local function test_expired_acquisition_changes_base_but_renew_drop_preserve_it()
  local s = fixture.init_state_repo("claim-base-operations")
  local id = fixture.file_item(s, "operation bases", "")
  assert(apply(s, id, "take", BASE, NOW).product_base == BASE)
  s = reopen(s)
  local acquired = apply(s, id, "take", NEXT_BASE, NOW + claim.LEASE_S)
  assert(acquired.product_base == NEXT_BASE,
    "expired history cannot override a fresh acquisition's resolved base")
  s = reopen(s)
  local renewed = apply(s, id, "renew", BASE, NOW + claim.LEASE_S + 1)
  assert(renewed.product_base == NEXT_BASE,
    "renew retains the lease base even if the request supplies another")
  s = reopen(s)
  local dropped = apply(s, id, "drop", BASE, NOW + claim.LEASE_S + 2)
  assert(dropped.product_base == NEXT_BASE,
    "drop retains the lease base even if the request supplies another")
  s = reopen(s)
  assert(fact(s, id).product_base == NEXT_BASE)
  assert(store.close(s))
end
