#!/usr/bin/env cosmic
-- `_work.cache`: the guard (reuse vs. rebuild, on a schema mismatch or
-- a hand-moved ref) and the incremental save/fetch paths, checked
-- against a cold rebuild's own row content throughout a real sequence
-- of saves and syncs across two clones. `_work.cachequery`'s
-- `lanes`/`find` wrappers have their own test file.

local cache = require("_work.cache")
local cachedb = require("_work.cachedb")
local cachequery = require("_work.cachequery")
local check = require("cosmic.check")
local child = require("cosmic.child")
local find = require("_work.find")
local fixture = require("_work.fixture")
local read = require("_work.read")
local fs = require("cosmic.fs")
local gate = require("_work.gitgate")
local gitbatch = require("_work.gitbatch")
local gitobj = require("_work.gitobj")
local gitrank = require("_work.gitrank")
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local publish = require("_work.publish")
local refs = require("_work.refs")
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
  -- `true`: the tree must actually exist for `commit_tree` below to
  -- build on it.
  local tree_sha = check.must(itemtree.build_tree(s.root, it, "", true))
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

-- The board's own outcome ranking is not a special case: it is the
-- board item's own `order` field, so ranking an outcome moves the
-- board item's OWN ref, under `refs/heads/items` — a digest move the
-- ordinary watched patterns already cover, with nothing extra needed.
local function test_ranking_an_outcome_moves_the_recorded_digest()
  local s = init_state_repo("board-order-digest")
  local root = file_item(s, "an outcome", "")
  check.must(cache.close(check.must(cache.open(s.root))))

  assert(gitrank.cmd_rank(s, root, "", "", true) == 0)

  local c = check.must(cache.open(s.root))
  local found = check.must(refs.for_each_ref(s.root,
      {"refs/heads/items", "refs/heads/ended", "refs/heads/board"}))
  local fresh = cachedb.digest_of(found)
  assert(cachedb.meta_get(c.db, "refs_digest") == fresh,
    "the cache's recorded digest reflects the board item's own ref moving")
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
  "items", "ranks", "builders", "speccers", "search", "cache_meta", "lanes",
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
-- (done), and a RANK change (an item's own `order`) — each checked
-- against a cold rebuild; then B syncs, saves of its own, and A syncs
-- LAST, so A's cache takes the fetch path rather than the save path,
-- checked once more.
local function test_incremental_cache_matches_a_cold_rebuild_throughout()
  local a, b = init_shared("cache-ratchet")
  local root_a, leaf_a = fixture.root_with_leaf(a)
  fixture.give_spec(a, leaf_a)
  assert(publish.sync(b))

  -- 1) BOUNDED: a fresh take against the doing bound leases and
  -- advances refs/heads/board/seq.
  assert(verbs.cmd_take(a, leaf_a, "session-a", 0, false, "") == 0)
  assert_cache_matches_cold_rebuild(a, "after a bounded take")

  -- 2) ENDED: the item's ref moves from refs/heads/items to refs/heads/ended.
  assert(verbs.cmd_done(a, leaf_a, "completed", true, "test: no PR to review") == 0)
  assert_cache_matches_cold_rebuild(a, "after an ended move")

  -- 3) RANK: an item's own `order` changes — `ranks` rows at
  -- `parent = root_a`. `store.list` first, matching every other step
  -- here (each a real verb that lists the whole board before writing):
  -- a fresh `a.board_digest` is what lets `commit_and_publish`'s own
  -- guard match the cache file's currently recorded one, rather than a
  -- stale digest from `take`'s list call two steps back silently
  -- skipping this patch.
  local other_leaf = file_item(a, "another workable slice", root_a)
  check.must(store.list(a))
  local root_it = check.must(store.load(a, root_a))
  root_it.order = {other_leaf}
  assert(gate.commit_and_publish(a, root_it, nil, "rank root_a's child",
      "rank"))
  assert_cache_matches_cold_rebuild(a, "after an order change")

  -- B syncs onto everything A just did, then makes a save of its own.
  assert(publish.sync(b))
  local b_leaf = file_item(b, "a slice b files", root_a)
  local b_leaf_it = check.must(store.load(b, b_leaf))
  b_leaf_it.claim = "session-b"
  assert(gate.commit_and_publish(b, b_leaf_it, nil, "claim b_leaf", "take"))

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

-- `open`'s digest check is `_work.refs.for_each_ref` under the hood
-- (`cachedb.fresh_digest`) — a caller that already took that exact
-- snapshot (`_work.store.list`'s own, say) hands its digest straight
-- in and the check never repeats the process.
local function test_open_with_a_known_digest_skips_for_each_ref()
  local s = init_state_repo("known-digest")
  file_item(s, "an item", "")
  check.must(cache.close(check.must(cache.open(s.root))))
  local digest = check.must(cachedb.fresh_digest(s.root))

  local calls = 0
  local real_for_each_ref = refs.for_each_ref
  refs.for_each_ref = function(root: string, patterns: {string}):
    {refs.RefEntry} | nil, string
    calls = calls + 1
    return real_for_each_ref(root, patterns)
  end
  local ok, c = pcall(cache.open, s.root, digest)
  refs.for_each_ref = real_for_each_ref
  if not ok then
    error(c, 0)
  end
  assert(calls == 0, "a known digest must skip open's own for-each-ref: " .. calls)
  check.must(cache.close(c as cache.Cache)) -- cast: pcall erases the union
end

-- The board's own outcome ranking is an ordinary item field, so a
-- fetch that moves the board item's own ref (ranking an outcome moves
-- it, the same as any other write to the board item) patches the
-- cache incrementally exactly like any other item's move: no special
-- "leave it stale" path is needed for it any more.
local function test_a_synced_outcome_rank_patches_the_cache_incrementally()
  local a, b = init_shared("outcome-rank-fetch")
  local root = file_item(a, "an outcome", "")
  assert(publish.sync(b))
  check.must(cache.close(check.must(cache.open(b.root))))
  local before_raw = check.must(sqlite.open(cache.path_of(b.root)))
  local before_digest = check.must(cachedb.meta_get(before_raw, "refs_digest"))
  check.must(before_raw:close())

  assert(gitrank.cmd_rank(a, root, "", "", true) == 0)
  assert(publish.sync(b))

  local after_raw = check.must(sqlite.open(cache.path_of(b.root)))
  local after_digest = check.must(cachedb.meta_get(after_raw, "refs_digest"))
  check.must(after_raw:close())
  assert(after_digest ~= before_digest,
    "the fetch's incremental patch records the board item's moved digest directly")

  local c = check.must(cache.open(b.root))
  local all = check.must(cachequery.items(c))
  local board_id = check.must(read.board(c))
  check.must(cache.close(c))
  local board = check.must(item.by_id(all)[board_id], "the board is among the items")
  assert(table.concat(board.order, " ") == root,
    ("the board's own order after the incremental patch: %s"):format(
      table.concat(board.order, " ")))
end

--- `store.list`, after an ordinary gated save, hydrates the saved
--- item's lease with the save's OWN new tip straight from the cache —
--- no fresh git object read at all, only the one `for-each-ref`
--- snapshot every `list` call takes for its own freshness digest.
--- Counted the way `_work/writepath_test.tl` counts git spawns: a
--- counting wrapper ahead of the real function, restored once the call
--- under test returns.
local function test_store_list_after_a_save_returns_the_new_tip_without_a_git_read()
  local s = init_state_repo("list-after-save-tip")
  local id = file_item(s, "an item", "")
  check.must(cache.close(check.must(cache.open(s.root))))

  local it = check.must(store.load(s, id))
  it.title = "retitled"
  assert(gate.commit_and_publish(s, it, nil, "retitle", "set"))

  local real_tip = (check.must(child.run(
        {"git", "rev-parse", "refs/heads/items/" .. id}, {cwd = s.root})).stdout
    :gsub("%s+$", ""))

  local for_each_ref_calls = 0
  local real_for_each_ref = refs.for_each_ref
  refs.for_each_ref = function(root: string, patterns: {string}):
    {refs.RefEntry} | nil, string
    for_each_ref_calls = for_each_ref_calls + 1
    return real_for_each_ref(root, patterns)
  end
  local batch_calls = 0
  local real_batch_session = gitbatch.batch_session
  gitbatch.batch_session = function(root: string): gitbatch.BatchSession | nil, string
    batch_calls = batch_calls + 1
    return real_batch_session(root)
  end
  local all, lerr = store.list(s)
  refs.for_each_ref = real_for_each_ref
  gitbatch.batch_session = real_batch_session
  assert(all ~= nil, lerr)

  assert(for_each_ref_calls == 1, ("store.list should cost exactly one "
      .. "for-each-ref snapshot: got %d"):format(for_each_ref_calls))
  assert(batch_calls == 0, ("store.list must not fall back to a git object "
      .. "batch read: got %d"):format(batch_calls))
  assert(s.leased_sha[id] == real_tip,
    "the lease reflects the save's new tip, read from the cache: "
    .. tostring(s.leased_sha[id]) .. " vs " .. real_tip)

  local found_it: item.Item = nil
  for _, i in ipairs(all) do
    if i.id == id then
      found_it = i
    end
  end
  assert(found_it ~= nil and found_it.title == "retitled",
    "store.list's own items carry the save's new title too")
end
