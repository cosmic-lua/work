--- The board cache's low-level shape and primitives: the file's path
--- and `.gitignore`, the ref-state digest and schema fingerprint that
--- decide reuse from rebuild, the `cache_meta`/`PRAGMA user_version`
--- bookkeeping every reader and writer checks against, and the
--- one-item patcher (`patch_item`) the save and fetch paths both
--- reduce to. Split out of `_work.cache` so that module (the guard,
--- `rebuild`, and the incremental save/fetch paths) and
--- `_work.cachequery` (the `lanes`/`find` reads built on top of it)
--- both stay under the repo's line cap without duplicating this part
--- between them.
---
--- Every connection this module opens is WAL with `synchronous = OFF`
--- (`open_conn`): the file is disposable — gitignored, and rebuilt
--- outright whenever it drifts or fails to read — so a torn write on a
--- crash costs a rebuild, never data worth an fsync. `rebuild` still
--- builds at a temp path and renames it into place, so it switches
--- that temp connection OUT of WAL (`journal_mode = DELETE`, which
--- checkpoints and removes the `-wal`/`-shm` sidecars itself) before
--- closing it — a plain rename only moves the one file it names, so a
--- sidecar left behind under the temp name would otherwise become
--- permanent litter.
local find = require("_work.find")
local fs = require("cosmic.fs")
local hash = require("cosmic.hash")
local index = require("_work.index")
local item = require("_work.item")
local refs = require("_work.refs")
local sqlite = require("cosmic.sqlite")

--- The cache connection: exactly `_work.index.Index`'s shape (`db`,
--- `specs`, `load_problems`), so every `_work.index`/`_work.find`
--- function that takes an `Index` takes a `Cache` unchanged. `specs`
--- is left empty once a connection is handed back — nothing reads it
--- after the table it seeds (`_work.find`'s `search`) is filled.
local type Cache = index.Index

--- The schema version this build writes and expects. `schema_fingerprint`
--- (below) now catches every shape change on its own — any edit to
--- the DDL this module, `_work.index`, or `_work.find` actually run —
--- so a mismatch on either one is treated exactly like a missing
--- file: `_work.cache.open` rebuilds rather than reading rows a
--- different shape wrote. A further hand bump of this constant is
--- therefore redundant for a DDL change specifically; it stays only
--- as an escape hatch for forcing every clone to rebuild for a reason
--- the fingerprint cannot see (a bug in how a row was interpreted, say).
local SCHEMA_VERSION < const > = 2

--- The cache file's name under a store root's `o/`.
local DB_FILENAME < const > = "board.db"

--- `cache_meta`, holding `refs_digest` (the ref state the file
--- reflects), `schema_version` (restated here as ordinary data too,
--- for a reader that would rather query it than read the connection's
--- own `PRAGMA user_version`), `schema_fingerprint` (`schema_fingerprint`
--- below — the actual DDL shape, catching a change `SCHEMA_VERSION`
--- was not bumped for), and `lanes`, the scheduled-lane observation
--- `_work.lanes` now reads and writes here instead of committing
--- `refs/heads/board/lanes`.
local EXTRA_DDL < const > = [[
CREATE TABLE cache_meta (
  k TEXT PRIMARY KEY,
  v TEXT NOT NULL
) STRICT, WITHOUT ROWID;

CREATE TABLE lanes (
  workflow TEXT PRIMARY KEY,
  conclusion TEXT NOT NULL,
  observed_at INTEGER NOT NULL
) STRICT, WITHOUT ROWID;
]]

--- The three ref namespaces the digest and the incremental patchers
--- watch — every ref a mutation or a fetch can move.
local WATCH_PATTERNS < const >: {string} = {"refs/heads/items", "refs/heads/ended", "refs/heads/board"}

--- The cache file's path for a given store root.
--- @param root string The store's root
--- @return string The path
local function path_of(root: string): string
  return fs.join(root, "o", DB_FILENAME)
end

--- Open a cache connection with this file's house rule applied: WAL
--- (so a reader never blocks a writer) plus `synchronous = OFF` (the
--- file is disposable, so the fsync WAL's own NORMAL default still
--- pays for is not worth it here). Every cache connection goes through
--- this rather than a bare `sqlite.open`.
--- @param path string The database file's path
--- @return sqlite.Database | nil The connection
--- @return string Error message
local function open_conn(path: string): sqlite.Database | nil, string
  local db, err = sqlite.open(path, {wal = true})
  if db == nil then
    return nil, err
  end
  local ok, serr = db:exec("PRAGMA synchronous = OFF")
  if not ok then
    local _c, _cerr = db:close()
    return nil, serr
  end
  return db
end

--- Best-effort removal of the cache file and any WAL/SHM sidecars
--- beside it — the clean slate a corrupt or stale file needs before a
--- rebuild writes a fresh one in its place. A rename over the main
--- file already replaces it atomically on its own; this only matters
--- for a sidecar a rename never touches.
--- @param root string The store's root
local function wipe(root: string)
  local path = path_of(root)
  for _, p in ipairs({path, path .. "-wal", path .. "-shm"}) do
    if fs.is_present(p) then
      local _ok, _err = fs.remove(p)
    end
  end
end

--- The digest `cache_meta.refs_digest` records: sha256 of every
--- watched ref's `"<refname> <sha>"` line, sorted, newline-joined —
--- deterministic regardless of `for-each-ref`'s own listing order.
--- @param entries {refs.RefEntry} A ref listing, e.g. from `refs_snapshot`
--- @return string The digest, hex-encoded
local function digest_of(entries: {refs.RefEntry}): string
  local lines: {string} = {}
  for _, e in ipairs(entries) do
    lines[#lines + 1] = e.refname .. " " .. e.sha
  end
  table.sort(lines)
  return hash.sha256_hex(table.concat(lines, "\n"))
end

--- Every watched ref's current name and object, in one process — the
--- ~7ms guard `_work.cache.open` pays to decide reuse, and what
--- `_work.cache.around_fetch` diffs before against after.
--- @param root string The store's root
--- @return {refs.RefEntry} | nil The refs found, possibly empty
--- @return string Error message
local function refs_snapshot(root: string): {refs.RefEntry} | nil, string
  return refs.for_each_ref(root, WATCH_PATTERNS)
end

--- The fresh digest for `root`'s CURRENT ref state — one
--- `refs_snapshot` plus `digest_of`.
--- @param root string The store's root
--- @return string | nil The digest
--- @return string Error message
local function fresh_digest(root: string): string | nil, string
  local entries, err = refs_snapshot(root)
  if entries == nil then
    return nil, err
  end
  return digest_of(entries), ""
end

--- Every watched ref's sha, keyed by ITEM id rather than refname — a
--- legacy id can still be filed under BOTH `refs/heads/items/<id>` and
--- `refs/heads/ended/<id>` at once (`_work.gitread`'s module header:
--- the residue of a resolution whose atomic push landed the create
--- half of an old-style namespace move and lost the delete half; a
--- resolution never moves a ref at all any more, so this is legacy
--- data, never something today's write path creates). Two passes,
--- `items/` first and `ended/` second so the second always overwrites
--- the first, make `ended/` the deterministic winner for such an id
--- regardless of `for-each-ref`'s own listing order — the safe
--- default `_work.gitread.pick_duplicate` also falls back to when it
--- cannot prove ancestry, though this function takes no `root` and so
--- never runs the `merge-base` check pick_duplicate can. The two can
--- therefore disagree on the rare id where `items/` truly is the
--- descendant; the consequence is bounded to this module's OWN
--- change-detection (an extra or slightly delayed patch), never to
--- the item data itself, which `_work.gitread.load_many`/`list`
--- always resolve with the real ancestry check. `refs/heads/board/*`
--- entries carry no id and are dropped here — `_work.cache.around_fetch`
--- diffs those through the whole digest instead.
--- @param entries {refs.RefEntry} A ref listing
--- @return {string: string} Item id -> sha
local function shas_by_item(entries: {refs.RefEntry}): {string: string}
  local out: {string: string} = {}
  for _, e in ipairs(entries) do
    local id = e.refname:match("^refs/heads/items/(.+)$")
    if id then
      out[id] = e.sha
    end
  end
  for _, e in ipairs(entries) do
    local id = e.refname:match("^refs/heads/ended/(.+)$")
    if id then
      out[id] = e.sha
    end
  end
  return out
end

--- Item ids whose sha differs between two `shas_by_item` maps —
--- appeared, disappeared, or moved, all read the same way: "this id's
--- current sha is not what it was."
--- @param before {string: string} Item id -> sha, pre-fetch
--- @param after {string: string} Item id -> sha, post-fetch
--- @return {string} Changed ids, sorted
local function changed_ids(before: {string: string}, after: {string: string}): {string}
  local seen: {string: boolean} = {}
  for id, sha in pairs(before) do
    if after[id] ~= sha then
      seen[id] = true
    end
  end
  for id, sha in pairs(after) do
    if before[id] ~= sha then
      seen[id] = true
    end
  end
  local out: {string} = {}
  for id in pairs(seen) do
    out[#out + 1] = id
  end
  table.sort(out)
  return out
end

--- Read one `cache_meta` value, nil when absent.
--- @param db sqlite.Database The connection
--- @param k string The key
--- @return string | nil The value
local function meta_get(db: sqlite.Database, k: string): string | nil
  local row = db:query_one("SELECT v FROM cache_meta WHERE k = ?", {k})
  if row == nil then
    return nil
  end
  return row.v as string -- cast: from any (sqlite row)
end

--- Write one `cache_meta` value, replacing whatever was there.
--- @param db sqlite.Database The connection
--- @param k string The key
--- @param v string The value
--- @return boolean True on success
--- @return string Error message
local function meta_set(db: sqlite.Database, k: string, v: string): boolean, string
  return db:exec([[
    INSERT INTO cache_meta(k, v) VALUES (?, ?)
    ON CONFLICT(k) DO UPDATE SET v = excluded.v
  ]], {k, v})
end

--- The connection's own `PRAGMA user_version`, -1 when it cannot be
--- read (never a valid schema version, so it always fails the guard).
--- @param db sqlite.Database The connection
--- @return integer The version
local function db_user_version(db: sqlite.Database): integer
  local row = db:query_one("PRAGMA user_version")
  if row == nil then
    return -1
  end
  return math.tointeger(row.user_version as number) or -1 -- cast: from any (sqlite row)
end

--- A connection's actual schema, fingerprinted: every object
--- `sqlite_master` carries a definition for (table, view, index —
--- STRICT tables, the FTS5 virtual table and its shadow tables alike),
--- sorted for a deterministic order, sha256'd. Reads the schema as
--- SQLite itself materialized it rather than concatenating DDL source
--- text, so it never drifts from a connection actually built with a
--- given DDL — including a detail like an FTS5 tokenizer argument that
--- lives inside the virtual table's own definition rather than in any
--- constant a caller could import directly.
--- @param db sqlite.Database The connection
--- @return string | nil The fingerprint, hex-encoded
--- @return string Error message
local function schema_fingerprint(db: sqlite.Database): string | nil, string
  local rows, err = db:query(
    "SELECT sql FROM sqlite_master WHERE sql IS NOT NULL ORDER BY type, name")
  if rows == nil then
    return nil, err
  end
  local parts: {string} = {}
  for row in rows do
    parts[#parts + 1] = row.sql as string -- cast: from any (sqlite row)
  end
  local ierr = rows:err()
  if ierr then
    return nil, ierr
  end
  return hash.sha256_hex(table.concat(parts, "\n"))
end

--- The schema `index.DDL`, `_work.find`'s search table, and
--- `EXTRA_DDL` produce TODAY, fingerprinted the same way `_work.cache.rebuild`
--- fingerprints the real file — built on a throwaway `:memory:`
--- connection rather than the file under test, since the whole point
--- is a value independent of whatever that file happens to hold. What
--- `_work.cache.open` compares `cache_meta.schema_fingerprint` against.
--- @return string | nil The fingerprint
--- @return string Error message
local function expected_schema_fingerprint(): string | nil, string
  local db, err = sqlite.open(":memory:")
  if db == nil then
    return nil, err
  end
  local iok, ierr = db:exec_script(index.DDL)
  if not iok then
    local _c, _cerr = db:close()
    return nil, ierr
  end
  local scratch: index.Index = {db = db, specs = {}, load_problems = {}}
  local fok, ferr = find.build(scratch)
  if not fok then
    local _c, _cerr = db:close()
    return nil, ferr
  end
  local eok, eerr = db:exec_script(EXTRA_DDL)
  if not eok then
    local _c, _cerr = db:close()
    return nil, eerr
  end
  local fp, fperr = schema_fingerprint(db)
  local _c, cerr = db:close()
  if fp == nil then
    return nil, fperr
  end
  if not _c then
    return nil, cerr
  end
  return fp
end

--- Refresh or drop one item's rows — `items`/`edges`/`builders`/
--- `speccers` (`_work.index`) and `search` (`_work.find`) — from what
--- the caller already holds, no git read at all: `_work.cache`'s
--- save-path and fetch-path patchers both reduce to this for one item.
--- `spec_body` nil means the caller made no spec change, so whatever
--- `search` last held for this id carries over unread; the caller
--- passes the current text (possibly "") whenever it DOES know it,
--- which for a fetch-path refresh is always.
--- @param c Cache An open, schema-valid cache
--- @param it item.Item The item, exactly as written
--- @param spec_body string | nil Its current spec text; nil to keep
--- whatever this id was last indexed with
--- @return boolean True on success
--- @return string Error message
local function patch_item(c: Cache, it: item.Item, spec_body: string | nil): boolean, string
  local prior: string | nil = nil
  if spec_body == nil then
    local row = c.db:query_one("SELECT spec FROM search WHERE id = ?", {it.id})
    if row ~= nil then
      prior = row.spec as string -- cast: from any (sqlite row)
    end
  end
  local dok, derr = index.delete_item(c.db, it.id)
  if not dok then
    return false, derr
  end
  local rok, rerr = find.remove_item(c, it.id)
  if not rok then
    return false, rerr
  end
  local iok, ierr = index.insert_item(c.db, it)
  if not iok then
    return false, ierr
  end
  return find.reindex_item(c, it, spec_body or prior or "")
end

--- Close the connection. Idempotent, like `Database.close` itself —
--- the same contract `_work.index.close` gives an ordinary `Index`.
--- @param c Cache The cache
--- @return boolean True on success
--- @return string Error message
local function close(c: Cache): boolean, string
  return c.db:close()
end

local record cachedb
  type Cache = Cache
  SCHEMA_VERSION: integer
  EXTRA_DDL: string
  path_of: function(root: string): string
  open_conn: function(path: string): sqlite.Database | nil, string
  wipe: function(root: string)
  digest_of: function(entries: {refs.RefEntry}): string
  refs_snapshot: function(root: string): {refs.RefEntry} | nil, string
  fresh_digest: function(root: string): string | nil, string
  shas_by_item: function(entries: {refs.RefEntry}): {string: string}
  changed_ids: function(before: {string: string}, after: {string: string}): {string}
  meta_get: function(db: sqlite.Database, k: string): string | nil
  meta_set: function(db: sqlite.Database, k: string, v: string): boolean, string
  db_user_version: function(db: sqlite.Database): integer
  schema_fingerprint: function(db: sqlite.Database): string | nil, string
  expected_schema_fingerprint: function(): string | nil, string
  patch_item: function(c: Cache, it: item.Item, spec_body: string | nil): boolean, string
  close: function(c: Cache): boolean, string
end

local M: cachedb = {
  SCHEMA_VERSION = SCHEMA_VERSION,
  EXTRA_DDL = EXTRA_DDL,
  path_of = path_of,
  open_conn = open_conn,
  wipe = wipe,
  digest_of = digest_of,
  refs_snapshot = refs_snapshot,
  fresh_digest = fresh_digest,
  shas_by_item = shas_by_item,
  changed_ids = changed_ids,
  meta_get = meta_get,
  meta_set = meta_set,
  db_user_version = db_user_version,
  schema_fingerprint = schema_fingerprint,
  expected_schema_fingerprint = expected_schema_fingerprint,
  patch_item = patch_item,
  close = close,
}

return M
