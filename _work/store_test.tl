#!/usr/bin/env cosmic
-- The store's read half: opening a state repository, resolving an id
-- prefix, and loading or listing items — including the tolerance a
-- flagged (content-invalid) item gets from `list`/`load` and the
-- refusal `stage` still gives it. The write and publish mechanics —
-- `save`'s own contracts (atomicity, the no-op success) and the
-- push/race machinery built on it — split into
-- `_work/storewrite_test.tl` alongside `_work/store.tl`'s own split
-- into `_work/storewrite.tl`; both files still use `save` freely, just
-- to seed fixtures.

local check = require("cosmic.check")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local gitobj = require("_work.gitobj")
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local ksuid = require("_work.ksuid")
local refs = require("_work.refs")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

local tmpdir = os.getenv("TEST_TMPDIR") or "/tmp"

-- Git reads a global (and system) config before it does anything, and
-- a config it cannot READ is fatal, not skipped: under the build
-- fence the home directory is outside the granted trees, so every git
-- call here — the fixtures' and the store's own — dies on
-- `unable to access '~/.gitconfig'`. Pointing this process at an
-- empty config makes the fixtures depend on no ambient state at all,
-- which is what a test of git behaviour wants regardless of the
-- fence. The store itself is deliberately NOT hermetic: a real
-- session's push needs the user's credentials and config.
local hermetic_config < const > = fs.join(tmpdir, "gitconfig-empty")
assert(fs.write(hermetic_config, ""))
assert(env.set("GIT_CONFIG_GLOBAL", hermetic_config))
assert(env.set("GIT_CONFIG_NOSYSTEM", "1"))

--- A fresh local-only state repo: `store.init_repo` (a bare git init
--- plus the `refs/heads/board/format` marker) — every item is a ref, so
--- there is nothing else to seed.
local function init_state_repo(name: string): string
  local root = fs.join(tmpdir, "store-" .. name)
  assert(fs.remove_all(root))
  assert(fs.make_dirs(root))
  assert(store.init_repo(root))
  return root
end

local counter = 0

--- A fresh deterministic id; later calls sort later.
local function fresh_id(): string
  counter = counter + 1
  return check.must(ksuid.encode(1700000000 + counter, ("\0"):rep(16)))
end

local PARENT = check.must(ksuid.encode(1690000000, ("\1"):rep(16)))

--- A minimal valid workable item (under a parent the store never
--- checks — graph rules are flow's, exercised in flow_test). The
--- claim doubles as the mutable payload the round-trip tests edit.
local function make_item(claim?: string): item.Item
  return check.must(item.decode({
        id = fresh_id(), title = "an item", parent = PARENT,
        claim = claim or "",
      }))
end

--- Write an item straight to its ref, past `stage`'s validator — a
--- pre-refusal writer's shape, or a hand edit from an older board.
--- Works for a brand-new id (no lease yet) as much as an existing one.
--- @param s store.Store The store
--- @param bad item.Item An item whose `item.problems` may be non-empty
local function write_unchecked(s: store.Store, bad: item.Item)
  -- `true`: the tree must actually exist for `commit_tree` below to
  -- build on it.
  local tree_sha = check.must(itemtree.build_tree(s.root, bad, store.read_spec(s, bad.id), true))
  local ref = s.leased_ref[bad.id] or ("refs/heads/items/" .. bad.id)
  local parent_sha = s.leased_sha[bad.id] or refs.ZERO_SHA
  local parents: {string} = {}
  if parent_sha ~= refs.ZERO_SHA then
    parents = {parent_sha}
  end
  local commit_sha = check.must(gitobj.commit_tree(s.root, {
        tree = tree_sha, parents = parents, message = "hand-edit",
        author_name = "test", author_email = "test@example.com",
        committer_name = "test", committer_email = "test@example.com",
      }))
  assert(refs.update_ref(s.root, ref, commit_sha, parent_sha))
end

-- `store.init_repo`/`open` have their own tests: `_work/storeinit_test.tl`.

local function test_resolve_prefixes()
  local root = init_state_repo("resolve")
  local s = check.must(store.open(root))
  local a = make_item()
  local b = make_item()
  assert(storewrite.save(s, a, "new a"))
  assert(storewrite.save(s, b, "new b"))
  assert(check.must(store.resolve(s, a.id)) == a.id, "full ids resolve")
  assert(check.must(store.resolve(s, a.id:sub(1, 26))) == a.id,
    "a unique prefix resolves")
  -- The deterministic ids share all but their trailing bytes, so the
  -- short common prefix is ambiguous by construction.
  local amb, aerr = store.resolve(s, a.id:sub(1, 4))
  assert(amb == nil and aerr:find("ambiguous", 1, true), "ambiguity is named")
  local none, nerr = store.resolve(s, "zzzz")
  assert(none == nil and nerr:find("no item", 1, true), "a miss is named")
end

-- `resolve`'s own one-shot lease is what lets the very next `load` of
-- the resolved id skip repeating this prefix's for-each-ref —
-- `_work.gitboard`'s handle route gets the symmetric guard in
-- `_work/gitboard_test.tl`; this is the prefix half.
local function test_resolve_leases_the_load_that_follows_a_prefix()
  local root = init_state_repo("resolve-leases-load")
  local s = check.must(store.open(root))
  local a = make_item()
  assert(storewrite.save(s, a, "new a"))
  local resolved = check.must(store.resolve(s, a.id:sub(1, 26)))
  assert(resolved == a.id, "the prefix resolves")

  local exact_pattern = {"refs/heads/items/" .. a.id, "refs/heads/ended/" .. a.id}
  local exact_calls = 0
  local real_for_each_ref = refs.for_each_ref
  refs.for_each_ref = function(croot: string, patterns: {string}):
    {refs.RefEntry} | nil, string
    if #patterns == 2 and patterns[1] == exact_pattern[1]
    and patterns[2] == exact_pattern[2] then
      exact_calls = exact_calls + 1
    end
    return real_for_each_ref(croot, patterns)
  end
  local ok, loaded = pcall(store.load, s, resolved)
  refs.for_each_ref = real_for_each_ref
  if not ok then
    error(loaded, 0)
  end
  assert(loaded ~= nil, "the load should succeed")
  assert(exact_calls == 0, "a resolved prefix's own load must not repeat "
    .. "the exact-ref for-each-ref an unleased load would run: " .. exact_calls)
end

-- An ordinary success and a terminal failure are never mistaken for
-- the no-op outcome.
local function test_is_noop_is_specific()
  assert(not store.is_noop(""), "an empty message is not a no-op")
  assert(not store.is_noop("git commit failed: disk full"),
    "an unrelated failure is not a no-op")
end

-- The bricking incident, restated for the ref layout: a `meta` blob is
-- `key: value` LINES, so a value that itself held a newline (the
-- original incident's multiline title) can no longer even reach
-- storage looking multiline — the line format is what refuses it now,
-- before `item.problems` ever gets a say. The tolerance this pins is
-- the same one either way: a content-invalid item — here, a PARENTLESS
-- item hand-edited to carry a claim, a shape only `write_unchecked`
-- can produce — must not abort `list`; the rest still reads, the bad
-- one comes back flagged, not dropped, and write-refusal is unchanged.
local function test_list_tolerates_a_flagged_item_but_stage_still_refuses()
  local root = init_state_repo("list-tolerant")
  local s = check.must(store.open(root))
  local good = make_item()
  assert(storewrite.save(s, good, "new good"))
  local bad = check.must(item.decode({id = fresh_id(), title = "a root"}))
  bad.claim = "session-x"
  local ok, serr = store.stage(s, bad)
  assert(not ok and serr:find("belong to worked items, never the board", 1, true) ~= nil,
    "stage refuses the same shape: " .. tostring(serr))
  write_unchecked(s, bad)
  local all = check.must(store.list(s))
  -- The board `init_repo` minted, `good`, and `bad`.
  assert(#all == 3, "the bad record is included, not dropped: got " .. #all)
  for _, it in ipairs(all) do
    assert(item.is_flagged(it) == (it.id == bad.id), "flagged iff bad")
  end
  local summary = store.flagged_summary(all)
  assert(summary:find(bad.id:sub(1, 8), 1, true) and
    summary:find("belong to worked items, never the board", 1, true), "summary: " .. summary)
end

-- Repairability falls out: `set` loads through this same tolerant
-- decode, so clearing the stray claim and saving clears the flag.
local function test_a_flagged_item_is_repairable_through_the_tolerant_decode()
  local root = init_state_repo("repair")
  local s = check.must(store.open(root))
  local seed = check.must(item.decode({id = fresh_id(), title = "a root"}))
  seed.claim = "session-x"
  write_unchecked(s, seed)
  local loaded = check.must(store.load(s, seed.id))
  assert(item.is_flagged(loaded), "the bad record still loads, flagged")
  loaded.claim = ""
  assert(storewrite.save(s, loaded, "set " .. seed.id:sub(1, 8) .. " claim"),
    "the repair commits: problems(it) is now empty")
  local fixed = check.must(store.load(s, seed.id))
  assert(not item.is_flagged(fixed) and fixed.claim == "", "clean")
  assert(store.flagged_summary(check.must(store.list(s))) == "",
    "listing recovers: nothing left flagged")
end
