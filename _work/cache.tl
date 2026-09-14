local boardread = require("_work.boardread")
local boardhistory = require("_work.boardhistory")
--- Disposable SQLite projection of the canonical native state head.
--- Cold reads rebuild once; mutations and refresh patch changed native paths.
--- Rebuild shares its decoded view and history through the invocation callback.
local stateread_clock = require("_work.stateread_clock")
local gitbatch = require("_work.gitbatch")
local statecache = require("_work.stateread_cache")
local format = require("_work.format")
local cachedb = require("_work.cachedb")
local cacherebuild = require("_work.cacherebuild")
local fs = require("cosmic.fs")
local refs = require("_work.refs")

local type Cache = cachedb.Cache
local SCHEMA_VERSION < const > = cachedb.SCHEMA_VERSION

--- Cold-build the cache file from scratch — `_work.cacherebuild`,
--- split out to keep this module under its line cap. Exported for the
--- equality ratchet, which forces one to compare against the
--- incrementally maintained file; ordinary reads go through `open`.
local rebuild = cacherebuild.rebuild

--- The guarded read every caller goes through: reuse the cache file as
--- it stands when its schema version, schema fingerprint, and stored
--- digest all match the board's CURRENT state, `rebuild` otherwise. A
--- cold clone (no file yet), a hand-moved ref (digest mismatch), a
--- version or fingerprint bump, AND a file that fails to validate for
--- any other reason (corruption a query surfaces as a genuine error,
--- not merely "no row") all take the same path: wipe whatever is
--- there and rebuild once. A second failure, from `rebuild` itself, is
--- returned as-is — this is a repair for a bad FILE, not a retry loop.
--- @param root string The store's root
--- @param known_digest string | nil A ref-snapshot digest the caller
--- already took (`_work.store.list`'s own, say) — skips this open's
--- otherwise-fresh `for-each-ref` when given
--- @return Cache | nil The cache
--- @return string Error message
local function open(root: string, known_digest?: string, snapshot?: {refs.RefEntry}, reader?: gitbatch.BatchSession, on_read?: function(boardread.View, boardhistory.History)): Cache | nil, string
  local path = cachedb.path_of(root)
  if fs.is_file(path) then
    local db = cachedb.open_conn(path)
    if db ~= nil then
      local fresh = known_digest
      if fresh == nil then
        fresh = cachedb.fresh_digest(root)
      end
      local expected_fp = cachedb.expected_schema_fingerprint()
      if fresh ~= nil and stateread_clock.fresh(db) and cachedb.db_user_version(db) == SCHEMA_VERSION
      and cachedb.meta_get(db, "refs_digest") == fresh
      and expected_fp ~= nil and cachedb.meta_get(db, "schema_fingerprint") == expected_fp then
        return {db = db, specs = {}, load_problems = {}}
      end
      local _c, _cerr = db:close()
    end
  end
  cachedb.wipe(root)
  return rebuild(root, snapshot, reader, on_read)
end

--- Patch a caller-owned fetch between two canonical native snapshots.
--- Cache failure discards derived state without invalidating a successful fetch.
local function around_fetch(root: string, fetch_fn: function(): boolean, string): boolean, string
  local path = cachedb.path_of(root)
  local before_entries: {refs.RefEntry} | nil = nil
  local before_native = ""
  if fs.is_file(path) then
    before_entries = cachedb.refs_snapshot(root)
    if before_entries ~= nil then
      local prior = format.state_head(root, before_entries)
      if prior == nil then
        -- Fetch may repair invalid state; discard its cache rather than label it legacy.
        cachedb.wipe(root)
        before_entries = nil
      else before_native = prior end
    end
  end
  local ok, err = fetch_fn()
  if not ok then return false, err end
  local after_entries, aerr = cachedb.refs_snapshot(root)
  if after_entries == nil then cachedb.wipe(root); return false, aerr end
  local native, nerr = format.state_head(root, after_entries)
  if native == nil then cachedb.wipe(root); return false, nerr end
  if before_entries == nil then return ok, err end
  local patched, _perr = statecache.patch(root, before_native, native)
  if not patched then cachedb.wipe(root) end
  return ok, err
end

--- Patch from the cache's recorded head after a caller-owned fetch or local CAS.
--- The native patch validates the schema and ancestry before trusting these rows.
local function after_fetch(root: string, head: string)
  if not fs.is_file(cachedb.path_of(root)) then return end
  local db = cachedb.open_conn(cachedb.path_of(root))
  if db == nil then cachedb.wipe(root); return end
  local before = cachedb.meta_get(db, "refs_digest")
  local _closed, _cerr = db:close()
  local patched, _perr = statecache.patch(root, before, head)
  if not patched then cachedb.wipe(root) end
end

local record cache
  after_fetch: function(root: string, head: string)
  type Cache = Cache
  SCHEMA_VERSION: integer
  path_of: function(root: string): string
  open: function(root: string, known_digest?: string, snapshot?: {refs.RefEntry}, reader?: gitbatch.BatchSession, on_read?: function(boardread.View, boardhistory.History)): Cache | nil, string
  rebuild: function(root: string, snapshot?: {refs.RefEntry}, reader?: gitbatch.BatchSession, on_read?: function(boardread.View, boardhistory.History)): Cache | nil, string
  close: function(c: Cache): boolean, string
  around_fetch: function(root: string,
  fetch_fn: function(): boolean, string): boolean, string
end

local M: cache = {
  after_fetch = after_fetch,
  SCHEMA_VERSION = SCHEMA_VERSION,
  path_of = cachedb.path_of,
  open = open,
  rebuild = rebuild,
  close = cachedb.close,
  around_fetch = around_fetch,
}

return M
