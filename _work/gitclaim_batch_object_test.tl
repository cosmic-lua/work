#!/usr/bin/env cosmic
-- End-to-end invariants for the claim representation: one immutable batch
-- object, one item-history bridge per member, and one atomic publication.
-- The race tests use a real local bare remote so they exercise receive-pack's
-- atomic ref transaction rather than merely inspecting generated argv.
local check = require("cosmic.check")
local claim = require("_work.claim")
local claimbatch = require("_work.claimbatch")
local fixture = require("_work.fixture")
local gitclaim = require("_work.gitclaim")
local gitread = require("_work.gitread")
local prepared = require("_work.prepared")
local refs = require("_work.refs")
local store = require("_work.store")

local NOW < const > = 2000000000
local BASE < const > = "0123456789012345678901234567890123456789"
local ALICE < const > = "0123456789abcdef0123456789abcdef"
local BOB < const > = "abcdef0123456789abcdef0123456789"

local function request(s: store.Store, id: string, batch: string,
    caller: string, action?: gitclaim.Action, now?: integer): gitclaim.Request
  local mode = refs.board_mode(s.root)
  return {root = s.root, id = id,
    source_ref = mode == "local" and gitclaim.target_item_ref(id)
    or gitclaim.remote_item_ref("origin", id),
    target_ref = gitclaim.target_item_ref(id), remote = "origin",
    batch = batch, caller = caller, action = action or "take",
    product_base = BASE, force = false, why = "", now = now or NOW}
end

local function prepare_set(s: store.Store, ids: {string}, batch: string,
    caller: string, action?: gitclaim.Action,
    now?: integer): gitclaim.Prepared
  local requests: {gitclaim.Request} = {}
  for _, id in ipairs(ids) do
    requests[#requests + 1] = request(s, id, batch, caller, action, now)
  end
  local result = gitclaim.prepare_batch(requests)
  assert(next(result.refused) == nil, result.refused.batch or "claim refused")
  return check.must(result.prepared)
end

local function member(p: gitclaim.Prepared, id: string): gitclaim.Member
  for _, m in ipairs(p.members) do
    if m.id == id then return m end
  end
  error("prepared batch has no member " .. id)
end

local function remote_tip(root: string, ref: string): string
  local r = check.must(store.git_ok(check.must(store.open(root)),
      {"ls-remote", "origin", ref}))
  return r.stdout:match("^(%x+)") or refs.ZERO_SHA
end

local function publish_remote(s: store.Store, p: gitclaim.Prepared): boolean
  local argv = check.must(gitclaim.push_argv(p, "origin", NOW))
  local ok, _err = prepared.execute(s.root, argv)
  return ok
end

local function test_every_item_bridge_points_at_one_shared_batch_object()
  local s = fixture.init_state_repo("claim-shared-batch-object")
  local a = fixture.file_item(s, "shared batch a", "")
  local b = fixture.file_item(s, "shared batch b", "")
  local p = prepare_set(s, {a, b}, "shared-object", ALICE)

  assert(#p.members == 2 and #p.batch.rows == 2)
  assert(p.deadline == NOW + claim.LEASE_S)
  local batch_updates = 0
  for _, u in ipairs(p.transaction.updates) do
    if u.ref == gitclaim.batch_ref(p.id) then
      batch_updates = batch_updates + 1
      assert(u.expected == refs.ZERO_SHA and u.next == p.batch.commit)
    end
  end
  assert(batch_updates == 1, "one append-only ref retains the shared batch object")
  for _, m in ipairs(p.members) do
    local loaded = check.must(gitread.load(s.root, m.id, m.new_sha, m.new_sha,
        NOW))
    assert(loaded.it.claim_batch == p.batch.commit,
      "every per-item bridge names the same immutable batch")
    local fact = check.must(claimbatch.read_fact(s.root, p.batch.commit, m.id))
    assert(fact.holder == ALICE and fact.expires_at == p.deadline)
  end
end

local function test_overlapping_sets_reject_wholly_but_disjoint_sets_both_land()
  local a_side, b_side = fixture.init_shared("claim-object-races")
  local a = fixture.file_item(a_side, "race a", "")
  local b = fixture.file_item(a_side, "race b", "")
  local c = fixture.file_item(a_side, "race c", "")
  local d = fixture.file_item(a_side, "race d", "")
  fixture.caller_fetch(b_side)

  local first = prepare_set(a_side, {a, b}, "overlap-one", ALICE)
  local overlap = prepare_set(b_side, {b, c}, "overlap-two", BOB)
  local c_before = remote_tip(b_side.root, gitclaim.target_item_ref(c))
  assert(publish_remote(a_side, first))
  assert(not publish_remote(b_side, overlap), "one stale member rejects the set")
  assert(remote_tip(b_side.root, gitclaim.target_item_ref(c)) == c_before,
    "the uncontested member of a rejected set must not move")
  assert(remote_tip(b_side.root, gitclaim.batch_ref(overlap.id)) == refs.ZERO_SHA,
    "the rejected set's shared batch ref must not leak")

  -- A lost race deliberately remains as a local receipt for diagnosis. This
  -- test has inspected the failure above, so discard that receipt before the
  -- fixture's next caller-owned fetch checks that every remaining receipt is
  -- confirmable.
  assert(refs.update_ref(b_side.root, overlap.transaction.staging_ref,
      refs.ZERO_SHA, overlap.transaction.manifest))

  fixture.caller_fetch(b_side)
  local disjoint = prepare_set(b_side, {c, d}, "disjoint", BOB)
  assert(publish_remote(b_side, disjoint))
  for _, m in ipairs(disjoint.members) do
    assert(remote_tip(b_side.root, m.target_ref) == m.new_sha)
  end
end

local function test_an_ordinary_item_write_fences_a_prepared_claim_set()
  local writer, claimant = fixture.init_shared("claim-object-item-fence")
  local raced = fixture.file_item(writer, "ordinary write race", "")
  local untouched = fixture.file_item(writer, "ordinary write companion", "")
  fixture.caller_fetch(claimant)
  local p = prepare_set(claimant, {raced, untouched}, "item-fence", BOB)
  local untouched_before = remote_tip(writer.root,
    gitclaim.target_item_ref(untouched))

  local it = check.must(store.load(writer, raced))
  it.title = "ordinary mutation wins"
  assert(require("_work.storewrite").save(writer, it, "ordinary mutation wins"))
  assert(require("_work.publish").publish(writer))
  fixture.caller_publish(writer)

  assert(not publish_remote(claimant, p),
    "a claim prepared from the old item tip must lose its item-ref lease")
  assert(remote_tip(writer.root, gitclaim.target_item_ref(untouched))
    == untouched_before, "claim rejection is atomic across untouched companions")
  assert(remote_tip(writer.root, gitclaim.batch_ref(p.id)) == refs.ZERO_SHA)
end

local function test_confirmation_needs_every_bridge_and_an_unexpired_batch()
  local s = fixture.init_state_repo("claim-object-confirmation")
  local a = fixture.file_item(s, "confirm a", "")
  local b = fixture.file_item(s, "confirm b", "")
  local p = prepare_set(s, {a, b}, "confirm-all", ALICE)
  assert(gitclaim.push_argv(p, "origin", p.deadline - 1) ~= nil)
  local argv, err = gitclaim.push_argv(p, "origin", p.deadline)
  assert(argv == nil and err:find("expired", 1, true), err)

  -- A partially observed atomic transaction grants no authority and retains
  -- its one receipt for diagnosis. The generic transaction classifier may
  -- call this pending or lost-race; it must never call it confirmed.
  assert(refs.set_board_mode(s.root, "remote"))
  for i, u in ipairs(p.transaction.updates) do
    local tracking = check.must(refs.tracking_ref(u.ref))
    local observed = i == 1 and u.next or u.expected
    if observed ~= refs.ZERO_SHA then
      assert(refs.update_ref(s.root, tracking, observed, refs.ZERO_SHA))
    end
  end
  local results = check.must(prepared.refresh(s.root))
  local found = false
  for _, result in ipairs(results) do
    if result.transaction.id == p.transaction.id then
      found = true
      assert(result.state ~= "confirmed", "partial visibility granted authority")
    end
  end
  assert(found)
  assert(check.must(refs.read_ref(s.root, p.transaction.staging_ref))
    == p.transaction.manifest, "incomplete confirmation keeps the receipt")
end

local function test_exact_expiry_allows_takeover_and_fences_stale_holder_work()
  local s = fixture.init_state_repo("claim-object-expiry")
  local id = fixture.file_item(s, "expiring claim", "")
  local acquired = prepare_set(s, {id}, "expiry-acquire", ALICE)
  assert(prepared.promote_local(s.root, acquired.transaction))

  local before = gitclaim.prepare_batch({request(s, id, "too-soon", BOB,
        "take", NOW + claim.LEASE_S - 1)})
  assert(before.prepared == nil and before.refused[id] ~= nil)

  local stale_tip = member(acquired, id).new_sha
  local takeover = prepare_set(s, {id}, "expiry-takeover", BOB, "take",
    NOW + claim.LEASE_S)
  assert(prepared.promote_local(s.root, takeover.transaction))
  local current = check.must(refs.read_ref(s.root, gitclaim.target_item_ref(id)))
  assert(current == member(takeover, id).new_sha and current ~= stale_tip)

  -- The old holder's detached successor still leases the acquisition bridge;
  -- the takeover has advanced that same item fence.
  local stale = check.must(require("_work.gitobj").commit_tree(s.root, {
        tree = check.must(require("_work.gitobj").tree_of(s.root, stale_tip)),
        parents = {stale_tip}, message = "stale holder write",
        author_name = ALICE, author_email = ALICE .. "@board",
        committer_name = "gitboard", committer_email = "gitboard@board"}))
  assert(not refs.update_ref(s.root, gitclaim.target_item_ref(id), stale, stale_tip),
    "post-takeover stale holder work must lose the item CAS")
end

local function test_renew_and_drop_keep_one_pointer_and_auditable_lineage()
  local s = fixture.init_state_repo("claim-object-renew-drop")
  local a = fixture.file_item(s, "renew drop a", "")
  local b = fixture.file_item(s, "renew drop b", "")
  local acquired = prepare_set(s, {a, b}, "lifecycle-acquire", ALICE)
  assert(prepared.promote_local(s.root, acquired.transaction))

  local renewed = prepare_set(s, {a, b}, "lifecycle-renew", ALICE, "renew",
    NOW + 60)
  assert(prepared.promote_local(s.root, renewed.transaction))
  for _, row in ipairs(renewed.batch.rows) do
    assert(row.operation == "renew" and row.root == acquired.batch.commit)
    assert(row.expires_at == NOW + 60 + claim.LEASE_S)
  end

  local dropped = prepare_set(s, {a, b}, "lifecycle-drop", ALICE, "drop",
    NOW + 120)
  assert(prepared.promote_local(s.root, dropped.transaction))
  for _, m in ipairs(dropped.members) do
    local it = check.must(gitread.load(s.root, m.id, m.new_sha, m.new_sha,
        NOW + 120)).it
    assert(it.claim_batch == dropped.batch.commit,
      "drop retains the latest batch pointer as an audit tombstone")
    local state, serr = claimbatch.read_state(s.root, it.claim_batch, m.id)
    assert(state == nil and serr == "", serr)
    local fact = check.must(claimbatch.read_fact(s.root, it.claim_batch, m.id))
    assert(fact.action == "drop" and fact.holder == "")
    assert(fact.root == acquired.batch.commit and fact.product_base == BASE)
  end
end
