#!/usr/bin/env cosmic
-- Native claim sets are one fenced state transition. These races exercise the
-- real remote publication path and canonical claims/<id> authority.
local boardread = require("_work.boardread")
local check = require("cosmic.check")
local claim = require("_work.claim")
local fixture = require("_work.fixture")
local stateclaim = require("_work.stateclaim")
local statepublish = require("_work.statepublish")
local staging = require("_work.statestaging")
local statewrite = require("_work.statewrite")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

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

local function prepare_set(s: store.Store, ids: {string}, caller: string,
    action?: stateclaim.Action, now?: integer): stateclaim.Result, staging.Receipt
  for _, id in ipairs(ids) do check.must(store.load(s, id)) end
  local result = stateclaim.prepare(s.root, s.state_head, requests(ids),
    action or "take", caller, now or NOW, false, "")
  assert(next(result.refused) == nil, result.refused.batch or result.refused[ids[1]])
  for _, dependency in ipairs(result.dependencies) do
    s.state_paths[dependency.path], s.state_reads[dependency.path] =
    dependency.id, dependency.id
  end
  assert(statewrite.transition(s, result.changes, "claim set",
      result.publish_by))
  return result, check.must(staging.load(s.root, s.state_receipt))
end

local function remote_head(s: store.Store): string
  local line = check.must(store.git_ok(s,
      {"ls-remote", "origin", "refs/heads/state"})).stdout
  return line:match("^(%x+)") or ""
end

local function test_one_transition_contains_every_claim_file()
  local s = fixture.init_state_repo("claim-native-set")
  local a = fixture.file_item(s, "shared transition a", "")
  local b = fixture.file_item(s, "shared transition b", "")
  local result, receipt = prepare_set(s, {a, b}, ALICE)
  assert(#result.members == 2 and #result.changes == 2)
  assert(#receipt.transitions == 1 and receipt.tip == s.state_head)
  local view = check.must(boardread.list(s.root, receipt.tip, NOW))
  assert(check.must(view.claims_by_id[a]).holder == ALICE)
  assert(check.must(view.claims_by_id[b]).holder == ALICE)
  assert(view.claims_by_id[a].expires_at == result.publish_by)
  assert(view.claims_by_id[b].expires_at == result.publish_by)
end

local function test_overlapping_sets_reject_wholly_but_disjoint_sets_land()
  local winner, loser = fixture.init_shared("claim-native-races")
  local a = fixture.file_item(winner, "race a", "")
  local b = fixture.file_item(winner, "race b", "")
  local c = fixture.file_item(winner, "race c", "")
  local d = fixture.file_item(winner, "race d", "")
  fixture.caller_fetch(loser)
  local _, first = prepare_set(winner, {a, b}, ALICE)
  local _, overlap = prepare_set(loser, {b, c}, BOB)
  assert(statepublish.execute(winner.root, first))
  local before = remote_head(loser)
  local ok, err = statepublish.execute(loser.root, overlap)
  assert(not ok and err == store.LOST_RACE, err)
  assert(remote_head(loser) == before, "the rejected set must move no state")
  fixture.caller_fetch(loser)
  local head = check.must(statepublish.head(loser.root, "origin"))
  local view = check.must(boardread.list(loser.root, head))
  assert(view.claims_by_id[a] ~= nil and view.claims_by_id[b] ~= nil)
  assert(view.claims_by_id[c] == nil,
    "the uncontested member of an overlapping set must not land")

  loser = check.must(store.open(loser.root))
  local _, disjoint = prepare_set(loser, {c, d}, BOB)
  assert(statepublish.execute(loser.root, disjoint))
  fixture.caller_fetch(loser)
  head = check.must(statepublish.head(loser.root, "origin"))
  view = check.must(boardread.list(loser.root, head))
  assert(view.claims_by_id[c] ~= nil and view.claims_by_id[d] ~= nil)
end

local function test_an_ordinary_item_write_fences_a_prepared_claim_set()
  local writer, claimant = fixture.init_shared("claim-native-item-fence")
  local raced = fixture.file_item(writer, "ordinary write race", "")
  local untouched = fixture.file_item(writer, "ordinary write companion", "")
  fixture.caller_fetch(claimant)
  local _, pending = prepare_set(claimant, {raced, untouched}, BOB)

  local it = check.must(store.load(writer, raced))
  it.title = "ordinary mutation wins"
  assert(storewrite.save(writer, it, "ordinary mutation wins"))
  assert(statepublish.publish(writer))
  fixture.caller_publish(writer)

  local ok, err = statepublish.execute(claimant.root, pending)
  assert(not ok and err == store.LOST_RACE, err)
  fixture.caller_fetch(claimant)
  local head = check.must(statepublish.head(claimant.root, "origin"))
  local view = check.must(boardread.list(claimant.root, head))
  assert(view.claims_by_id[raced] == nil)
  assert(view.claims_by_id[untouched] == nil,
    "a stale member must reject every claim file in the set")
end

local function test_exact_expiry_allows_takeover_and_changes_identity()
  local s = fixture.init_state_repo("claim-native-expiry")
  local id = fixture.file_item(s, "expiring claim", "")
  local acquired, _receipt = prepare_set(s, {id}, ALICE)
  assert(statepublish.publish(s))
  local identity = acquired.members[1].claim_root
  local early = stateclaim.prepare(s.root, s.state_head, requests({id}),
    "take", BOB, NOW + claim.LEASE_S - 1, false, "")
  assert(early.refused[id] ~= nil and #early.changes == 0)
  local takeover = stateclaim.prepare(s.root, s.state_head, requests({id}),
    "take", BOB, NOW + claim.LEASE_S, false, "")
  assert(next(takeover.refused) == nil)
  assert(takeover.members[1].claim_root ~= identity)
end

local function test_renew_and_drop_keep_the_acquisition_identity()
  local s = fixture.init_state_repo("claim-native-renew-drop")
  local a = fixture.file_item(s, "renew drop a", "")
  local b = fixture.file_item(s, "renew drop b", "")
  local acquired = prepare_set(s, {a, b}, ALICE)
  assert(statepublish.publish(s))
  local root_a, root_b = acquired.members[1].claim_root,
  acquired.members[2].claim_root
  local renewed = prepare_set(s, {a, b}, ALICE, "renew", NOW + 60)
  assert(renewed.members[1].claim_root == root_a)
  assert(renewed.members[2].claim_root == root_b)
  assert(statepublish.publish(s))
  local dropped = prepare_set(s, {a, b}, ALICE, "drop", NOW + 120)
  assert(dropped.members[1].claim_root == root_a)
  assert(dropped.members[2].claim_root == root_b)
  assert(statepublish.publish(s))
  local view = check.must(boardread.list(s.root, s.state_head))
  assert(view.claims_by_id[a] == nil and view.claims_by_id[b] == nil)
end
