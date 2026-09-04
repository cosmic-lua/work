#!/usr/bin/env cosmic
-- `_work.cache`: the guard (reuse vs. rebuild, on a schema mismatch or
-- a hand-moved ref) and the incremental save/fetch paths, checked
-- against a cold rebuild's own row content throughout a real sequence
-- of saves and syncs across two clones. `_work.cachequery`'s
-- `lanes`/`find` wrappers have their own test file.

local cache = require("_work.cache")
local check = require("cosmic.check")
local cmp = require("_work.gitcompare")
local find = require("_work.find")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local gitobj = require("_work.gitobj")
local itemtree = require("_work.itemtree")
local publish = require("_work.publish")
local sqlite = require("cosmic.sqlite")
local store = require("_work.store")
local verbs = require("_work.gitverbs")

local init_state_repo = fixture.init_state_repo
local init_shared = fixture.init_shared
local file_item = fixture.file_item

local function test_open_builds_the_file_and_it_carries_the_item()
  local s = init_state_repo("open-builds")
  local id = file_item(s, "a fresh item", "")
  local c = check.must(cache.open(s.root))
  assert(fs.is_file(cache.path_of(s.root)), "the cache file now exists")
  local row = check.must(c.db:query_one("SELECT title FROM items WHERE id = ?", {id}))
  assert(row.title == "a fresh item", tostring(row.title))
  check.must(cache.close(c))
end

local function test_a_hand_moved_ref_forces_a_rebuild()
  local s = init_state_repo("hand-moved")
  local id = file_item(s, "before the hand edit", "")
  check.must(cache.close(check.must(cache.open(s.root))))

  -- Move the ref with plain git plumbing — never through the tool, so
  -- none of the incremental hooks fire and the cache file is left
  -- holding the OLD title.
  local it = check.must(store.load(s, id))
  local old_sha = s.leased_sha[id]
  it.title = "changed behind the tool's back"
  local tree_sha = check.must(itemtree.build_tree(s.root, it, ""))
  local commit_sha = check.must(gitobj.commit_tree(s.root, {
        tree = tree_sha, parents = {old_sha}, message = "hand edit",
        author_name = "test", author_email = "test@example.com",
        committer_name = "test", committer_email = "test@example.com",
      }))
  assert(store.git_ok(s, {"update-ref", "refs/heads/items/" .. id, commit_sha}))

  local c = check.must(cache.open(s.root))
  local row = check.must(c.db:query_one("SELECT title FROM items WHERE id = ?", {id}))
  assert(row.title == "changed behind the tool's back",
    "the digest mismatch forced a rebuild: " .. tostring(row.title))
  check.must(cache.close(c))
end

local function test_a_wrong_schema_version_forces_a_rebuild()
  local s = init_state_repo("wrong-version")
  file_item(s, "an item", "")
  check.must(cache.close(check.must(cache.open(s.root))))

  local raw = check.must(sqlite.open(cache.path_of(s.root)))
  assert(raw:exec("PRAGMA user_version = 999999"))
  check.must(raw:close())

  local c = check.must(cache.open(s.root))
  local row = check.must(c.db:query_one("PRAGMA user_version"))
  assert(math.tointeger(row.user_version) == cache.SCHEMA_VERSION,
    "the version mismatch forced a rebuild back to the current schema")
  check.must(cache.close(c))
end

--- A deterministic, sorted dump of one table's rows: every column,
--- rendered `k=v` pairs joined and sorted, so row order — which
--- neither side promises — never causes a false mismatch.
--- @param db sqlite.Database The connection
--- @param table_name string The table (or FTS5 table) to dump
--- @return {string} One rendered line per row, sorted
local function dump(db: sqlite.Database, table_name: string): {string}
  local out: {string} = {}
  for row in assert(db:query("SELECT * FROM " .. table_name)) do
    local keys: {string} = {}
    for k in pairs(row) do
      keys[#keys + 1] = k
    end
    table.sort(keys)
    local parts: {string} = {}
    for _, k in ipairs(keys) do
      parts[#parts + 1] = k .. "=" .. tostring(row[k])
    end
    out[#out + 1] = table.concat(parts, "|")
  end
  table.sort(out)
  return out
end

--- Every table the cache's schema carries — `_work.index`'s own plus
--- `_work.find`'s search table and `_work.cache`'s own two.
local CACHE_TABLES < const >: {string} = {
  "items", "edges", "builders", "speccers", "search", "cache_meta", "lanes",
}

--- Compare `s`'s LIVE, incrementally maintained cache file against a
--- fresh cold `rebuild` of the same board, table by table — the
--- equality ratchet. Reads the live file directly (never through
--- `cache.open`, which would silently repair a mismatch instead of
--- exposing one), then forces a cold rebuild, which overwrites the
--- file with the freshly built one — so the file the next incremental
--- step patches is the just-proven-equal rebuild, not a divergent
--- leftover.
--- @param s store.Store The store
--- @param label string What step this check is verifying, for the message
local function assert_cache_matches_cold_rebuild(s: store.Store, label: string)
  local raw = check.must(sqlite.open(cache.path_of(s.root)))
  local live: {string: {string}} = {}
  for _, t in ipairs(CACHE_TABLES) do
    live[t] = dump(raw, t)
  end
  check.must(raw:close())

  local fresh = check.must(cache.rebuild(s.root))
  for _, t in ipairs(CACHE_TABLES) do
    local cold = dump(fresh.db, t)
    assert(#live[t] == #cold,
      ("%s: %s has %d live row(s), %d cold — %s"):format(
        label, t, #live[t], #cold, table.concat(live[t], "; ")))
    for i, row in ipairs(live[t]) do
      assert(row == cold[i], ("%s: %s row %d differs\n live: %s\n cold: %s")
        :format(label, t, i, row, cold[i]))
    end
  end
  local hits = check.must(find.query(fresh, "outcome", 20))
  local cold_hits = check.must(find.similar(fresh, "outcome the second"))
  assert(hits ~= nil and cold_hits ~= nil, label .. ": find still works post-rebuild")
  check.must(cache.close(fresh))
end

-- The equality ratchet (D6): a sequence of saves in clone A — a
-- BOUNDED save (a fresh take against the doing bound), an ENDED move
-- (done), and an EDGE change (compare) — each checked against a cold
-- rebuild; then B syncs, saves of its own, and A syncs LAST, so A's
-- cache takes the fetch path rather than the save path, checked once
-- more.
local function test_incremental_cache_matches_a_cold_rebuild_throughout()
  local a, b = init_shared("cache-ratchet")
  local root_a, leaf_a = fixture.root_with_leaf(a)
  fixture.give_spec(a, leaf_a)
  local outcome_b = file_item(a, "the second outcome, unrelated", "")
  assert(cmp.cmd_compare(a, outcome_b, root_a) == 0)
  assert(publish.sync(b))

  -- 1) BOUNDED: a fresh take against the doing bound leases and
  -- advances refs/heads/board/seq.
  assert(verbs.cmd_take(a, leaf_a, "session-a", 0, false, "") == 0)
  assert_cache_matches_cold_rebuild(a, "after a bounded take")

  -- 2) ENDED: the item's ref moves from refs/heads/items to refs/heads/ended.
  assert(verbs.cmd_done(a, leaf_a, "completed", true, "test: no PR to review") == 0)
  assert_cache_matches_cold_rebuild(a, "after an ended move")

  -- 3) EDGE: a `beats` edge lands on the winner's own row.
  local other_leaf = file_item(a, "another workable slice", root_a)
  assert(cmp.cmd_compare(a, other_leaf, outcome_b) == 0)
  assert_cache_matches_cold_rebuild(a, "after an edge change")

  -- B syncs onto everything A just did, then makes a save of its own.
  assert(publish.sync(b))
  local b_leaf = file_item(b, "a slice b files", root_a)
  assert(cmp.cmd_compare(b, b_leaf, other_leaf) == 0)

  -- A syncs LAST: its cache takes the FETCH path, not the save path.
  assert(publish.sync(a))
  assert_cache_matches_cold_rebuild(a, "after A's fetch of B's save")
end
