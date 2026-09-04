#!/usr/bin/env cosmic
-- `_work.cache`: the guard (reuse vs. rebuild, on a schema mismatch or
-- a hand-moved ref) and the incremental save/fetch paths, checked
-- against a cold rebuild's own row content throughout a real sequence
-- of saves and syncs across two clones. `_work.cachequery`'s
-- `lanes`/`find` wrappers have their own test file.

local cache = require("_work.cache")
local cachedb = require("_work.cachedb")
local check = require("cosmic.check")
local child = require("cosmic.child")
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

--- A stored `schema_fingerprint` that no longer matches what today's
--- code would produce forces a rebuild — the same path a real DDL
--- edit takes, exercised here by corrupting the recorded value
--- directly rather than editing `_work.index`/`_work.find`'s DDL
--- (owned by other, concurrent work): either way, `open`'s comparison
--- against `cachedb.expected_schema_fingerprint()` is what fires.
local function test_a_schema_fingerprint_mismatch_forces_a_rebuild()
  local s = init_state_repo("fingerprint-mismatch")
  local id = file_item(s, "before the fingerprint drifted", "")
  check.must(cache.close(check.must(cache.open(s.root))))

  local raw = check.must(sqlite.open(cache.path_of(s.root)))
  assert(raw:exec(
      "UPDATE cache_meta SET v = 'not-a-real-fingerprint' WHERE k = 'schema_fingerprint'"))
  check.must(raw:close())

  local c = check.must(cache.open(s.root))
  local row = check.must(c.db:query_one("SELECT title FROM items WHERE id = ?", {id}))
  assert(row.title == "before the fingerprint drifted",
    "the fingerprint mismatch forced a rebuild: " .. tostring(row.title))
  local fp = check.must(cachedb.meta_get(c.db, "schema_fingerprint"))
  assert(fp == check.must(cachedb.expected_schema_fingerprint()),
    "the rebuild recorded today's real fingerprint, not the corrupted one")
  check.must(cache.close(c))
end

--- A file truncated to half its size — SQLite can still read the
--- header (page 1) but a b-tree page allocated later in the file, a
--- table created and filled after `items`/`search` almost certainly
--- is, is simply gone — self-heals: `open` cannot validate what it
--- read, wipes it, and rebuilds from git rather than surfacing the
--- corruption to a caller.
local function test_a_truncated_file_self_heals_on_open()
  local s = init_state_repo("truncated")
  local id = file_item(s, "before truncation", "")
  check.must(cache.close(check.must(cache.open(s.root))))

  local path = cache.path_of(s.root)
  local size = check.must(fs.stat(path)):size()
  assert(size > 0, "the cache file is non-empty")
  check.must(fs.truncate(path, size // 2))

  local c = check.must(cache.open(s.root))
  local row = check.must(c.db:query_one("SELECT title FROM items WHERE id = ?", {id}))
  assert(row.title == "before truncation",
    "a truncated file still self-heals to the real board: " .. tostring(row.title))
  check.must(cache.close(c))
end

--- Zeroing exactly `cache_meta`'s own root page — found through
--- `sqlite_master` rather than guessed, so the corruption lands
--- precisely rather than by luck — leaves `items`/`search` intact but
--- makes any query against `cache_meta` fail outright. `open` still
--- answers with a correct board: the failed read is exactly the kind
--- of error that forces a rebuild, not merely a value mismatch.
local function test_a_corrupted_cache_meta_page_self_heals_on_open()
  local s = init_state_repo("corrupt-meta")
  local id = file_item(s, "before the corruption", "")
  check.must(cache.close(check.must(cache.open(s.root))))

  local path = cache.path_of(s.root)
  local raw = check.must(sqlite.open(path))
  local meta_row = check.must(raw:query_one(
      "SELECT rootpage FROM sqlite_master WHERE name = 'cache_meta'"))
  local size_row = check.must(raw:query_one("PRAGMA page_size"))
  check.must(raw:close())
  local rootpage = math.tointeger(meta_row.rootpage) or 0
  local page_size = math.tointeger(size_row.page_size) or 0
  assert(rootpage > 0 and page_size > 0, "cache_meta has a real root page")

  local bytes = check.must(fs.read(path))
  local offset = (rootpage - 1) * page_size
  local zeroed = bytes:sub(1, offset) .. string.rep("\0", page_size)
  .. bytes:sub(offset + page_size + 1)
  check.must(fs.write(path, zeroed))

  local c = check.must(cache.open(s.root))
  local row = check.must(c.db:query_one("SELECT title FROM items WHERE id = ?", {id}))
  assert(row.title == "before the corruption",
    "a corrupted cache_meta page still self-heals to the real board: "
    .. tostring(row.title))
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

--- Whether every cache table, as the file stands right now, equals a
--- cold rebuild of the same board — `assert_cache_matches_cold_rebuild`'s
--- comparison, but returned rather than asserted, since the concurrent
--- test below has two acceptable outcomes to choose between rather
--- than one to demand.
--- @param s store.Store The store
--- @return boolean True when every table matches
local function cache_matches_cold_rebuild(s: store.Store): boolean
  local raw = check.must(sqlite.open(cache.path_of(s.root)))
  local live: {string: {string}} = {}
  for _, t in ipairs(CACHE_TABLES) do
    live[t] = dump(raw, t)
  end
  check.must(raw:close())
  local fresh = check.must(cache.rebuild(s.root))
  local same = true
  for _, t in ipairs(CACHE_TABLES) do
    local cold = dump(fresh.db, t)
    if #live[t] ~= #cold then
      same = false
    else
      for i, row in ipairs(live[t]) do
        if row ~= cold[i] then
          same = false
        end
      end
    end
  end
  check.must(cache.close(fresh))
  return same
end

-- Two REAL processes, not two in-process calls: `o/bin/gitboard set`
-- against ONE clone, each renaming a DIFFERENT item, started together
-- so their guard/write/patch cycles are free to interleave inside the
-- SAME `o/board.db` file. Each mutation is unbounded (a plain `set`
-- never leases `refs/heads/board/seq`), so nothing here exercises the
-- store's own race handling — this is purely about the cache file
-- surviving two writers at once. Either outcome is correct: the two
-- incremental patches interleaved cleanly and the file matches a cold
-- rebuild outright, or one guard's before-digest went stale between
-- the two (the OTHER process's write landed in between) and that
-- patch was skipped by design, left for the next `open` to catch up
-- — which this test forces immediately rather than waiting for one.
-- `cosmic.sqlite`'s 5000ms busy timeout is what keeps a transaction
-- from ever seeing the other mid-write instead of erroring outright;
-- without it a `SQLITE_BUSY` would be a live possibility here on a
-- slower disk, caught by self-heal (`cache.open`'s wipe-and-rebuild)
-- rather than surfacing as a failure.
local function test_two_processes_racing_the_cache_never_corrupts_it()
  local s = init_state_repo("two-process")
  local id_x = file_item(s, "x, raced from process one", "")
  local id_y = file_item(s, "y, raced from process two", "")
  check.must(cache.close(check.must(cache.open(s.root))))

  local gitboard < const > = "o/bin/gitboard"
  local h1 = check.must(child.start({gitboard, "set", id_x,
        "--title", "x, renamed by process one", "--dir", s.root}))
  local h2 = check.must(child.start({gitboard, "set", id_y,
        "--title", "y, renamed by process two", "--dir", s.root}))
  local r1 = check.must(h1:wait(30000))
  local r2 = check.must(h2:wait(30000))
  assert(r1.ok, "process one failed: " .. r1.stderr)
  assert(r2.ok, "process two failed: " .. r2.stderr)

  if not cache_matches_cold_rebuild(s) then
    -- A skipped patch: still stale, by design, until the next open.
    -- Force that next open now and require it to have fully caught up.
    check.must(cache.close(check.must(cache.open(s.root))))
    assert(cache_matches_cold_rebuild(s),
      "the next open must fully reconcile a stale cache left by the race")
  end

  local it_x = check.must(store.load(s, id_x))
  local it_y = check.must(store.load(s, id_y))
  assert(it_x.title == "x, renamed by process one", it_x.title)
  assert(it_y.title == "y, renamed by process two", it_y.title)
end
