#!/usr/bin/env cosmic
-- Format-3 to format-4 cutover: every item receives a first-parent bridge,
-- embedded claims become immutable singleton batches, and one atomic prepared
-- transaction also advances the format marker.
local cache = require("_work.cache")
local check = require("cosmic.check")
local child = require("cosmic.child")
local claim = require("_work.claim")
local claimbatch = require("_work.claimbatch")
local fixture = require("_work.fixture")
local format = require("_work.format")
local gitmigrate = require("_work.gitmigrate")
local gitobj = require("_work.gitobj")
local refs = require("_work.refs")
local store = require("_work.store")

local function install_v3(root: string): string
  local current = check.must(refs.read_ref(root, "refs/heads/board/format"))
  local blob = check.must(gitobj.hash_object_write(root, format.PREVIOUS .. "\n"))
  local tree = check.must(gitobj.mktree_write(root, {
        {mode = "100644", otype = "blob", sha = blob, name = "format"},
      }))
  local prior = check.must(gitobj.commit_tree(root, {
        tree = tree, parents = {current}, message = "fixture format 3",
        author_name = "test", author_email = "test@example.com",
        committer_name = "test", committer_email = "test@example.com",
      }))
  assert(refs.update_ref(root, "refs/heads/board/format", prior, current))
  return prior
end

local function item_tips(root: string): {string: string}
  local found = check.must(refs.for_each_ref_raw(root,
      {"refs/heads/items", "refs/heads/ended"}))
  local out: {string: string} = {}
  for _, entry in ipairs(found) do out[entry.refname] = entry.sha end
  return out
end

local function nkeys(values: {string: string}): integer
  local n = 0
  for _ in pairs(values) do n = n + 1 end
  return n
end

--- Advance one item with an actual format-3 tree. The format-4 encoder omits
--- embedded claim fields by design, so constructing this through Store.save
--- would silently test an unclaimed item rather than the migration boundary.
local function set_embedded_claim(s: store.Store, id: string,
    holder: string, base: string): integer
  local target = "refs/heads/items/" .. id
  local prior = check.must(refs.read_ref(s.root, target))
  local objects = check.must(gitobj.cat_file_batch(s.root, {prior .. ":meta"}))
  local meta = assert(objects[prior .. ":meta"], "fixture item has meta")
  local meta_sha = check.must(gitobj.hash_object_write(s.root,
      meta.content .. "claim: " .. holder .. "\nclaim_base: " .. base .. "\n"))
  local old_tree = check.must(gitobj.tree_of(s.root, prior))
  local trees = check.must(gitobj.cat_file_batch(s.root, {old_tree}))
  local tree_object = assert(trees[old_tree], "fixture item has a tree")
  local entries = gitobj.parse_tree(tree_object.content)
  for _, entry in ipairs(entries) do
    if entry.name == "meta" then entry.sha = meta_sha end
  end
  local tree = check.must(gitobj.mktree_write(s.root, entries))
  local at = os.time()
  local date = ("%d +0000"):format(at)
  local commit = check.must(gitobj.commit_tree(s.root, {tree = tree,
        parents = {prior}, message = ("claim acquire %s by %s")
        :format(id:sub(1, 8), holder), author_name = holder,
        author_email = holder .. "@board", author_date = date,
        committer_name = "gitboard", committer_email = "gitboard@board",
        committer_date = date, op = "claim-acquire"}))
  assert(refs.update_ref(s.root, target, commit, prior))
  return at
end

local function test_local_migration_bridges_every_item_and_rebuilds_schema_8()
  local s = fixture.init_state_repo("migrate-local-v4")
  local _root, leaf = fixture.root_with_leaf(s)
  check.must(store.close(s))
  local before = item_tips(s.root)
  install_v3(s.root)

  local outcome = check.must(gitmigrate.migrate(s.root))
  assert(outcome.applied and outcome.bridged == nkeys(before))
  local after = item_tips(s.root)
  for ref, old in pairs(before) do
    assert(after[ref] ~= old, "migration must invalidate old item lease: " .. ref)
    local parent = check.must(child.run({"git", "show", "-s", "--format=%P",
          after[ref]}, {cwd = s.root}))
    assert(parent.ok and parent.stdout:gsub("%s+$", "") == old,
      "bridge is a first-parent successor")
  end
  local reopened = check.must(store.open(s.root))
  assert((check.must(store.load(reopened, leaf)).claim_batch or "") == "")
  check.must(store.close(reopened))
  local c = check.must(cache.open(s.root))
  local version = check.must(c.db:query_one("PRAGMA user_version"))
  assert(math.tointeger(version.user_version) == 8)
  check.must(cache.close(c))
end

local function test_active_embedded_claim_becomes_a_singleton_hold_without_renewal()
  local s = fixture.init_state_repo("migrate-active-v4")
  local _root, leaf = fixture.root_with_leaf(s)
  local base = ("a"):rep(40)
  local acquired = set_embedded_claim(s, leaf, "legacy-caller", base)
  check.must(store.close(s))
  install_v3(s.root)
  local migrated = check.must(gitmigrate.migrate(s.root, acquired + 60))
  assert(migrated.applied and migrated.batches == 1)

  local reopened = check.must(store.open(s.root))
  local it = check.must(store.load(reopened, leaf))
  assert(it.claim == "legacy-caller" and it.claim_base == base)
  assert((it.claim_batch or "") ~= "")
  local fact = check.must(claimbatch.read_fact(s.root, it.claim_batch or "", leaf))
  assert(fact.action == "hold" and fact.holder == "legacy-caller")
  assert(fact.acquired_at == acquired and fact.renewed_at == acquired)
  assert(fact.expires_at == acquired + claim.LEASE_S,
    "migration preserves the old deadline rather than renewing it")
  local batch_ref = "refs/heads/claim-batches/"
  .. check.must(claimbatch.read(s.root, it.claim_batch or "")).id
  assert(check.must(refs.read_ref(s.root, batch_ref)) == it.claim_batch)
  check.must(store.close(reopened))
end

local function test_expired_embedded_claim_becomes_an_inactive_tombstone()
  local s = fixture.init_state_repo("migrate-expired-v4")
  local _root, leaf = fixture.root_with_leaf(s)
  local acquired = set_embedded_claim(s, leaf, "old-caller", ("b"):rep(40))
  check.must(store.close(s))
  install_v3(s.root)
  assert(check.must(gitmigrate.migrate(s.root,
        acquired + claim.LEASE_S + 1)).applied)
  local reopened = check.must(store.open(s.root))
  local it = check.must(store.load(reopened, leaf))
  assert(it.claim == "" and (it.claim_batch or "") ~= "")
  local fact = check.must(claimbatch.read_fact(s.root, it.claim_batch or "", leaf))
  assert(fact.action == "drop" and fact.holder == "")
  assert(fact.product_base == ("b"):rep(40))
  check.must(store.close(reopened))
end

local function test_remote_migration_is_one_transaction_over_every_ref()
  local s = fixture.init_state_repo("migrate-remote-v4")
  local _root, leaf = fixture.root_with_leaf(s)
  set_embedded_claim(s, leaf, "remote-caller", ("c"):rep(40))
  check.must(store.close(s))
  local marker = install_v3(s.root)
  local local_refs = check.must(refs.for_each_ref_raw(s.root,
      {"refs/heads/items", "refs/heads/ended", "refs/heads/board"}))
  for _, entry in ipairs(local_refs) do
    local tracking = check.must(refs.tracking_ref(entry.refname))
    assert(refs.update_ref(s.root, tracking, entry.sha, refs.ZERO_SHA))
  end
  assert(refs.set_board_mode(s.root, "remote"))
  local before = item_tips(s.root)

  local outcome = check.must(gitmigrate.migrate(s.root))
  assert(not outcome.applied and outcome.transaction ~= nil)
  local tx = outcome.transaction
  assert(#tx.updates == nkeys(before) + outcome.batches + 1,
    "one transaction contains all item bridges, batches, and format")
  local saw_format, saw_batch = false, false
  for _, update in ipairs(tx.updates) do
    if update.ref == "refs/heads/board/format" then
      saw_format = true
      assert(update.expected == marker)
    elseif update.ref:match("^refs/heads/claim%-batches/") then
      saw_batch = true
      assert(update.expected == refs.ZERO_SHA)
    end
  end
  assert(saw_format and saw_batch)
  assert(check.must(format.inspect(s.root)).content == format.PREVIOUS .. "\n")
  for ref, old in pairs(before) do assert(item_tips(s.root)[ref] == old) end
end

local function test_migration_is_idempotent_and_refuses_unknown_predecessor()
  local s = fixture.init_state_repo("migrate-idempotent-v4")
  local current = check.must(gitmigrate.migrate(s.root))
  assert(current.current and current.applied and current.transaction == nil)

  local prior = check.must(refs.read_ref(s.root, "refs/heads/board/format"))
  local blob = check.must(gitobj.hash_object_write(s.root, "99\n"))
  local tree = check.must(gitobj.mktree_write(s.root, {
        {mode = "100644", otype = "blob", sha = blob, name = "format"},
      }))
  local unknown = check.must(gitobj.commit_tree(s.root, {tree = tree,
        parents = {prior}, message = "unknown format", author_name = "test",
        author_email = "test@example.com", committer_name = "test",
        committer_email = "test@example.com"}))
  assert(refs.update_ref(s.root, "refs/heads/board/format", unknown, prior))
  local denied, err = gitmigrate.migrate(s.root)
  assert(denied == nil and err:find("99", 1, true) ~= nil, err)
end
