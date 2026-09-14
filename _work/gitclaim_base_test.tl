#!/usr/bin/env cosmic
-- Fresh acquisitions resolve the current base; renew and drop retain one
-- acquisition identity and never accept a replacement base.
local boardread = require("_work.boardread")
local boardtree = require("_work.boardtree")
local check = require("cosmic.check")
local claim = require("_work.claim")
local fixture = require("_work.fixture")
local gitclaim_cli = require("_work.gitclaim_cli")
local graph = require("_work.gitgraph")
local product_fixture = require("_work.commit_flow_fixture")
local stateclaim = require("_work.stateclaim")
local statepublish = require("_work.statepublish")
local statewrite = require("_work.statewrite")
local store = require("_work.store")

local CALLER < const > = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
local BASE < const > = "0123456789012345678901234567890123456789"
local NEXT_BASE < const > = string.rep("a", 40)

local function recorded(s: store.Store, id: string): boardtree.Claim | nil
  return check.must(boardread.load(s.root, s.state_head, id)).claim
end

local function apply(s: store.Store, id: string, action: stateclaim.Action,
    base: string, now: integer): stateclaim.Member
  local result = stateclaim.prepare(s.root, s.state_head,
    {{id = id, product_base = base}}, action, CALLER, now, false, "")
  assert(next(result.refused) == nil, result.refused[id] or result.refused.batch)
  for _, dependency in ipairs(result.dependencies) do
    s.state_paths[dependency.path], s.state_reads[dependency.path] =
    dependency.id, dependency.id
  end
  local session, op = s.session, s.op
  s.session, s.op = CALLER, action == "renew" and "renew"
  or action == "drop" and "drop" or "claim"
  assert(statewrite.transition(s, result.changes, "claim base fixture",
      result.publish_by))
  assert(statepublish.publish(s))
  s.session, s.op = session, op
  return result.members[1]
end

local function test_repo_less_acquisition_records_the_current_state()
  local s = fixture.init_state_repo("claim-base-board-only")
  local id = fixture.file_item(s, "board-only work", "")
  local base = s.state_head
  fixture.claim_item(s, id, CALLER)
  local value = check.must(recorded(s, id))
  assert(value.product_base == base)
end

local function test_repo_less_reacquisition_uses_the_new_current_state()
  local s = fixture.init_state_repo("claim-base-reacquire")
  local id = fixture.file_item(s, "reacquired work", "")
  fixture.claim_item(s, id, CALLER)
  local first = check.must(recorded(s, id))
  fixture.drop_claim(s, id, CALLER, "released")
  local current = s.state_head
  fixture.claim_item(s, id, CALLER)
  local second = check.must(recorded(s, id))
  assert(second.product_base == current)
  assert(second.product_base ~= first.product_base)
end

local function test_repaired_product_target_replaces_the_released_board_base()
  local s = fixture.init_state_repo("claim-base-repaired")
  local _, id = fixture.root_with_leaf(s)
  fixture.claim_item(s, id, CALLER)
  local board_base = check.must(recorded(s, id)).product_base
  fixture.drop_claim(s, id, CALLER, "switching to product work")
  local product = product_fixture.product("claim-base-repaired")
  assert(graph.cmd_set(s, id, nil, "acme/widgets", "main") == 0)
  assert(gitclaim_cli.cmd_claim(s, {id}, "take", CALLER, "origin",
      product.root, false, "", false) == 0)
  local value = check.must(recorded(s, id))
  assert(value.product_base == product.base)
  assert(value.product_base ~= board_base)
end

local function test_expired_take_changes_base_but_renew_and_drop_keep_identity()
  local s = fixture.init_state_repo("claim-base-operations")
  local id = fixture.file_item(s, "operation bases", "")
  local now = os.time()
  local acquired_id = boardtree.mint_claim_id()
  fixture.raw_seed_claim(s, id, {id = acquired_id, holder = CALLER,
      acquired_at = now - claim.LEASE_S - 10,
      renewed_at = now - claim.LEASE_S - 10,
      expires_at = now - 10, product_base = BASE},
    "historical expired acquisition")
  local first = check.must(recorded(s, id))
  assert(first.product_base == BASE and first.id == acquired_id)

  local taken = apply(s, id, "take", NEXT_BASE, now)
  local second = check.must(recorded(s, id))
  assert(second.product_base == NEXT_BASE and second.id == taken.claim_root)
  assert(second.id ~= first.id)

  local renewed = apply(s, id, "renew", BASE, now + 1)
  local third = check.must(recorded(s, id))
  assert(third.product_base == NEXT_BASE and renewed.claim_root == second.id)
  local dropped = apply(s, id, "drop", BASE, now + 2)
  assert(dropped.claim_root == second.id and recorded(s, id) == nil)
end
