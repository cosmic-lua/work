--- The board cache's low-level shape and primitives: the file's path
--- and `.gitignore`, the ref-state digest that decides reuse from
--- rebuild, and the `cache_meta`/`PRAGMA user_version` bookkeeping
--- every reader and writer checks against. Split out of `_work.cache`
--- so that module (the guard, `rebuild`, and the incremental save/fetch
--- paths) and `_work.cachequery` (the `lanes`/`find` reads built on
--- top of it) both stay under the repo's line cap without duplicating
--- this part between them.
local fs = require("cosmic.fs")
local hash = require("cosmic.hash")
local index = require("_work.index")
local refs = require("_work.refs")
local sqlite = require("cosmic.sqlite")

--- The cache connection: exactly `_work.index.Index`'s shape (`db`,
--- `specs`, `load_problems`), so every `_work.index`/`_work.find`
--- function that takes an `Index` takes a `Cache` unchanged. `specs`
--- is left empty once a connection is handed back — nothing reads it
--- after the table it seeds (`_work.find`'s `search`) is filled.
local type Cache = index.Index

--- The schema version this build writes and expects. Bumped whenever
--- the DDL below (or `_work.index`'s, or `_work.find`'s search table)
--- changes shape — a mismatch is treated exactly like a missing file:
--- `_work.cache.open` rebuilds rather than reading rows a different
--- version wrote.
local SCHEMA_VERSION < const > = 1

--- The cache file's name under a store root's `o/`.
local DB_FILENAME < const > = "board.db"

--- `cache_meta`, holding `refs_digest` (the ref state the file
--- reflects) and `schema_version` (restated here as ordinary data
--- too, for a reader that would rather query it than read the
--- connection's own `PRAGMA user_version`), and `lanes`, the
--- scheduled-lane observation `_work.lanes` now reads and writes here
--- instead of committing `refs/board/lanes`.
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
local WATCH_PATTERNS < const >: {string} = {"refs/items", "refs/ended", "refs/board"}

--- The cache file's path for a given store root.
--- @param root string The store's root
--- @return string The path
local function path_of(root: string): string
  return fs.join(root, "o", DB_FILENAME)
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

--- Every watched ref's sha, keyed by ITEM id rather than refname — an
--- id's ref namespace can change (`refs/items/<id>` moving to
--- `refs/ended/<id>`) without the id itself changing, so keying this
--- way makes an ended-move read as "this id's sha changed" exactly
--- like an ordinary edit, never as one id disappearing and a
--- different one appearing. `refs/board/*` entries carry no id and
--- are dropped here — `_work.cache.around_fetch` diffs those through
--- the whole digest instead.
--- @param entries {refs.RefEntry} A ref listing
--- @return {string: string} Item id -> sha
local function shas_by_item(entries: {refs.RefEntry}): {string: string}
  local out: {string: string} = {}
  for _, e in ipairs(entries) do
    local id = e.refname:match("^refs/items/(.+)$") or e.refname:match("^refs/ended/(.+)$")
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
  digest_of: function(entries: {refs.RefEntry}): string
  refs_snapshot: function(root: string): {refs.RefEntry} | nil, string
  fresh_digest: function(root: string): string | nil, string
  shas_by_item: function(entries: {refs.RefEntry}): {string: string}
  changed_ids: function(before: {string: string}, after: {string: string}): {string}
  meta_get: function(db: sqlite.Database, k: string): string | nil
  meta_set: function(db: sqlite.Database, k: string, v: string): boolean, string
  db_user_version: function(db: sqlite.Database): integer
  close: function(c: Cache): boolean, string
end

local M: cachedb = {
  SCHEMA_VERSION = SCHEMA_VERSION,
  EXTRA_DDL = EXTRA_DDL,
  path_of = path_of,
  digest_of = digest_of,
  refs_snapshot = refs_snapshot,
  fresh_digest = fresh_digest,
  shas_by_item = shas_by_item,
  changed_ids = changed_ids,
  meta_get = meta_get,
  meta_set = meta_set,
  db_user_version = db_user_version,
  close = close,
}

return M
