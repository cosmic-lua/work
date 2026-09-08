#!/usr/bin/env cosmic
-- Format-2 to format-3 migration: one marker ref moves through the same
-- prepared/CAS transport as every other durable mutation; item histories are
-- untouched and the disposable cache is rebuilt rather than migrated in place.
local cache = require("_work.cache")
local claim = require("_work.claim")
local check = require("cosmic.check")
local child = require("cosmic.child")
local fixture = require("_work.fixture")
local format = require("_work.format")
local gitmigrate = require("_work.gitmigrate")
local gitobj = require("_work.gitobj")
local prepared = require("_work.prepared")
local refs = require("_work.refs")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

--- Replace the local marker with a real format-2 commit and return its sha.
local function install_v2(root: string): string
  local current = check.must(refs.read_ref(root, "refs/heads/board/format"))
  local blob = check.must(gitobj.hash_object_write(root, format.PREVIOUS .. "\n"))
  local tree = check.must(gitobj.mktree_write(root, {
        {mode = "100644", otype = "blob", sha = blob, name = "format"},
      }))
  local old = check.must(gitobj.commit_tree(root, {
        tree = tree, parents = {current}, message = "fixture format 2",
        author_name = "test", author_email = "test@example.com",
        committer_name = "test", committer_email = "test@example.com",
      }))
  assert(refs.update_ref(root, "refs/heads/board/format", old, current))
  return old
end

local function item_tips(root: string): string
  local r = check.must(child.run({"git", "for-each-ref",
        "--format=%(refname) %(objectname)", "refs/heads/items",
        "refs/heads/ended"}, {cwd = root}))
  assert(r.ok, r.stderr)
  return r.stdout
end

local function test_local_migration_only_moves_format_and_rebuilds_cache()
  local s = fixture.init_state_repo("migrate-local")
  local id = fixture.file_item(s, "an unchanged format-2 item", "")
  local it = check.must(store.load(s, id))
  check.must(cache.close(check.must(cache.open(s.root))))
  check.must(store.close(s))
  local before_items = item_tips(s.root)
  install_v2(s.root)

  local current, refusal = format.require_current(s.root)
  assert(not current and refusal:find("gitboard migrate", 1, true) ~= nil, refusal)
  local old_reader = check.must(store.open(s.root))
  local listed, lerr = store.list(old_reader)
  assert(listed == nil and lerr:find("gitboard migrate", 1, true) ~= nil, lerr)
  it.title = "must not write before migration"
  local saved, serr = storewrite.save(s, it, "forbidden format-2 write")
  assert(not saved and serr:find("gitboard migrate", 1, true) ~= nil, serr)

  local outcome = check.must(gitmigrate.migrate(s.root))
  assert(not outcome.current and outcome.applied and outcome.transaction ~= nil)
  assert(item_tips(s.root) == before_items, "migration rewrote an item ref")
  assert(check.must(format.inspect(s.root)).content == format.blob())
  assert(#check.must(prepared.list(s.root)) == 0,
    "a confirmed local migration cleans its prepared ref")
  local rebuilt = check.must(cache.open(s.root))
  local version = check.must(rebuilt.db:query_one("PRAGMA user_version"))
  assert(math.tointeger(version.user_version) == cache.SCHEMA_VERSION)
  check.must(cache.close(rebuilt))
end

local function test_remote_migration_stages_without_changing_confirmed_state()
  local s = fixture.init_state_repo("migrate-remote")
  fixture.file_item(s, "a remotely confirmed format-2 item", "")
  check.must(store.close(s))
  local old = install_v2(s.root)
  local local_refs = check.must(refs.for_each_ref_raw(s.root,
      {"refs/heads/items", "refs/heads/ended", "refs/heads/board"}))
  for _, entry in ipairs(local_refs) do
    local tracking = check.must(refs.tracking_ref(entry.refname))
    assert(refs.update_ref(s.root, tracking, entry.sha, refs.ZERO_SHA))
  end
  assert(refs.set_board_mode(s.root, "remote"))

  local outcome = check.must(gitmigrate.migrate(s.root))
  assert(not outcome.current and not outcome.applied and outcome.transaction ~= nil)
  local tx = outcome.transaction
  assert(#tx.updates == 1)
  assert(tx.updates[1].ref == "refs/heads/board/format")
  assert(tx.updates[1].expected == old)
  local observed = check.must(format.inspect(s.root))
  assert(observed.content == format.PREVIOUS .. "\n",
    "preparation must not alter caller-fetched canonical state")
  assert(check.must(refs.read_ref(s.root, "refs/heads/board/format")) == old,
    "preparation must not alter the local target head either")

  -- Stand in for the caller's push+fetch. Only then does refresh confirm and
  -- clean the staged transaction; the normal cache open rebuilds from v3.
  local tracked = check.must(refs.tracking_ref("refs/heads/board/format"))
  assert(refs.update_ref(s.root, tracked, tx.updates[1].next, old))
  local refreshed = check.must(prepared.refresh(s.root))
  assert(#refreshed == 1 and refreshed[1].state == "confirmed")
  assert(check.must(format.inspect(s.root)).content == format.blob())
  local c = check.must(cache.open(s.root))
  check.must(cache.close(c))
end

local function test_live_legacy_claim_requires_a_quiet_expiry_window()
  local s = fixture.init_state_repo("migrate-legacy-claim")
  local _outcome, leaf = fixture.root_with_leaf(s)
  local it = check.must(store.load(s, leaf))
  it.claim = "legacy-caller"
  assert(storewrite.save(s, it, "legacy claim"))
  fixture.caller_publish(s)
  check.must(store.close(s))
  install_v2(s.root)

  local now = os.time()
  local denied, err = gitmigrate.migrate(s.root, now)
  assert(denied == nil, "a live legacy claim must block migration")
  assert(err:find("two-hour lease", 1, true) ~= nil, err)

  -- Waiting out the maximum ordinary lease plus tolerated future skew makes
  -- the exact same unchanged item history safe to interpret under format 3.
  local migrated = check.must(gitmigrate.migrate(s.root,
      now + claim.LEASE_S + claim.FUTURE_SKEW_S + 1))
  assert(migrated.applied)
end

local function test_migration_is_idempotent_and_refuses_unknown_predecessors()
  local s = fixture.init_state_repo("migrate-idempotent")
  local already = check.must(gitmigrate.migrate(s.root))
  assert(already.current and already.applied and already.transaction == nil)

  local current = check.must(refs.read_ref(s.root, "refs/heads/board/format"))
  local blob = check.must(gitobj.hash_object_write(s.root, "99\n"))
  local tree = check.must(gitobj.mktree_write(s.root, {
        {mode = "100644", otype = "blob", sha = blob, name = "format"},
      }))
  local unknown = check.must(gitobj.commit_tree(s.root, {
        tree = tree, parents = {current}, message = "unknown format",
        author_name = "test", author_email = "test@example.com",
        committer_name = "test", committer_email = "test@example.com",
      }))
  assert(refs.update_ref(s.root, "refs/heads/board/format", unknown, current))
  local denied, err = gitmigrate.migrate(s.root)
  assert(denied == nil and err:find("99", 1, true) ~= nil, err)
end
