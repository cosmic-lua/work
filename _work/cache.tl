--- The board's persistent, incrementally maintained SQLite mirror:
--- one file, `o/board.db` under a checkout's own store root, carrying
--- `_work.index`'s schema plus `_work.find`'s search table, a `lanes`
--- table, and a `cache_meta` table recording which ref state the file
--- reflects (`_work.cachedb`, this module's low-level half). It is
--- DERIVED and never truth — gitignored, rebuilt whenever it is
--- missing, mismatched in schema, or behind the refs it mirrors — but
--- unlike `_work.index`'s own `:memory:` connection, it survives one
--- verb invocation to the next, so a session's second `find` (or
--- `sync`'s lane read, or `new`'s duplicate check — `_work.cachequery`,
--- built on top of this module) costs a handful of small queries
--- against an already-open file rather than a fresh whole-board read.
---
--- `open` is the guard every reader goes through: a fresh
--- `for-each-ref` digest over `refs/heads/items`, `refs/heads/ended` and
--- `refs/heads/board`, compared against what the file last recorded, decides
--- reuse or a cold `rebuild`. `guard`/`after_save` and `around_fetch`
--- are the incremental half: a mutation or a fetch that moves refs
--- patches exactly the items whose refs moved, rather than paying for
--- `rebuild`'s whole-board read on every write. Deliberately built on
--- `root: string` rather than `_work.store`'s `Store`: `_work.store`
--- has no need of this module at all, and it is `_work.gitgate`'s
--- `commit_and_publish` (which already requires `_work.store`) that
--- calls `guard`/`after_save` around every mutation's `store.save`,
--- and `_work.publish` that wraps its fetches with `around_fetch` —
--- a `Store` dependency here would close a cycle against both.
local cachedb = require("_work.cachedb")
local find = require("_work.find")
local fs = require("cosmic.fs")
local gitread = require("_work.gitread")
local index = require("_work.index")
local proc = require("cosmic.proc")
local refs = require("_work.refs")
local sqlite = require("cosmic.sqlite")

local type Cache = cachedb.Cache
local SCHEMA_VERSION < const > = cachedb.SCHEMA_VERSION

--- Cold-build the cache file from scratch: every item and spec this
--- root's board carries, `_work.index`'s tables, `_work.find`'s
--- search table, `cache_meta` and `lanes` — written to a temp file
--- beside the real path and renamed into place once complete, so a
--- reader never sees a half-built file. Exported for the equality
--- ratchet, which forces one to compare against the incrementally
--- maintained file; ordinary reads go through `open`.
--- @param root string The store's root
--- @return Cache | nil The freshly built cache
--- @return string Error message
local function rebuild(root: string): Cache | nil, string
  local board, berr = gitread.list(root)
  if board == nil then
    return nil, berr
  end
  local ids: {string} = {}
  for _, it in ipairs(board.items) do
    ids[#ids + 1] = it.id
  end
  local specs = gitread.read_specs(root, board.shas_by_id, ids)
  local dir_ok, dir_err = fs.make_dirs(fs.join(root, "o"))
  if not dir_ok then
    return nil, dir_err
  end
  local final_path = cachedb.path_of(root)
  local tmp_path = ("%s.tmp.%d"):format(final_path, proc.getpid())
  if fs.is_present(tmp_path) then
    local rm_ok, rm_err = fs.remove(tmp_path)
    if not rm_ok then
      return nil, rm_err
    end
  end
  local db, derr = sqlite.open(tmp_path, {wal = false})
  if db == nil then
    return nil, derr
  end
  local ddl_ok, ddl_err = db:exec_script(index.DDL)
  if not ddl_ok then
    local _c, _cerr = db:close()
    return nil, ddl_err
  end
  local tx_ok, tx_err = db:transaction(function(tx: sqlite.Database): boolean, string
      for _, it in ipairs(board.items) do
        local iok, ierr = index.insert_item(tx, it)
        if not iok then
          return false, ierr
        end
      end
      return true, ""
    end)
  if not tx_ok then
    local _c, _cerr = db:close()
    return nil, tx_err
  end
  local c: Cache = {db = db, specs = specs, load_problems = {}}
  local fok, ferr = find.build(c)
  if not fok then
    local _c, _cerr = db:close()
    return nil, ferr
  end
  local eok, eerr = db:exec_script(cachedb.EXTRA_DDL)
  if not eok then
    local _c, _cerr = db:close()
    return nil, eerr
  end
  local pvok, pverr = db:exec(("PRAGMA user_version = %d"):format(SCHEMA_VERSION))
  if not pvok then
    local _c, _cerr = db:close()
    return nil, pverr
  end
  local digest, digerr = cachedb.fresh_digest(root)
  if digest == nil then
    local _c, _cerr = db:close()
    return nil, digerr
  end
  local sok, serr = cachedb.meta_set(db, "refs_digest", digest)
  if sok then
    sok, serr = cachedb.meta_set(db, "schema_version", tostring(SCHEMA_VERSION))
  end
  if not sok then
    local _c, _cerr = db:close()
    return nil, serr
  end
  local cok, cerr = db:close()
  if not cok then
    return nil, cerr
  end
  local mvok, mverr = fs.move(tmp_path, final_path)
  if not mvok then
    return nil, mverr
  end
  local reopened, roerr = sqlite.open(final_path, {wal = false})
  if reopened == nil then
    return nil, roerr
  end
  return {db = reopened, specs = {}, load_problems = {}}
end

--- The guarded read every caller goes through: reuse the cache file as
--- it stands when its schema version and stored digest both match the
--- board's CURRENT ref state, `rebuild` otherwise. A cold clone (no
--- file yet), a hand-moved ref (digest mismatch), and a version bump
--- (`PRAGMA user_version` mismatch) all take the same rebuild path.
--- @param root string The store's root
--- @return Cache | nil The cache
--- @return string Error message
local function open(root: string): Cache | nil, string
  local path = cachedb.path_of(root)
  if fs.is_file(path) then
    local db = sqlite.open(path, {wal = false})
    if db ~= nil then
      local fresh = cachedb.fresh_digest(root)
      if fresh ~= nil and cachedb.db_user_version(db) == SCHEMA_VERSION
      and cachedb.meta_get(db, "refs_digest") == fresh then
        return {db = db, specs = {}, load_problems = {}}
      end
      local _c, _cerr = db:close()
    end
  end
  return rebuild(root)
end

--- Refresh or drop one item's rows — `items`/`edges`/`builders`/
--- `speccers` (`_work.index`) and `search` (`_work.find`) — reading
--- it fresh from git rather than trusting whatever the caller already
--- holds, since a fetch can land a version neither side observed
--- directly.
--- @param c Cache An open, schema-valid cache
--- @param root string The store's root
--- @param id string The item id
--- @return boolean True on success
--- @return string Error message
local function patch_item(c: Cache, root: string, id: string): boolean, string
  local dok, derr = index.delete_item(c.db, id)
  if not dok then
    return false, derr
  end
  local rok, rerr = find.remove_item(c, id)
  if not rok then
    return false, rerr
  end
  local loaded, lerr = gitread.load(root, id)
  if loaded == nil then
    -- Genuinely gone (never true of an item this board minted, but a
    -- pruned local ref counts): the delete above is the whole fix.
    if lerr ~= nil and lerr:match("^no item ") ~= nil then
      return true, ""
    end
    return false, lerr
  end
  local iok, ierr = index.insert_item(c.db, loaded.it)
  if not iok then
    return false, ierr
  end
  local spec = gitread.read_spec(root, {loaded.ref})
  return find.reindex_item(c, loaded.it, spec)
end

--- Patch exactly `ids` inside one transaction, then advance the
--- digest to the board's fresh, post-write state — the shared body of
--- `after_save` and `around_fetch` once each has decided the cache was
--- valid immediately before its write and knows which ids moved.
--- @param root string The store's root
--- @param ids {string} Item ids to refresh
--- @return boolean True on success (including nothing to do)
--- @return string Error message
local function apply_patch(root: string, ids: {string}): boolean, string
  if #ids == 0 then
    return true, ""
  end
  local path = cachedb.path_of(root)
  if not fs.is_file(path) then
    return true, ""
  end
  local db = sqlite.open(path, {wal = false})
  if db == nil then
    -- Best effort: a cache the tool cannot even open is `open`'s
    -- problem to rebuild next time, never this write's to fail over.
    return true, ""
  end
  local c: Cache = {db = db, specs = {}, load_problems = {}}
  local tok, terr = db:transaction(function(tx: sqlite.Database): boolean, string
      local txc: Cache = {db = tx, specs = {}, load_problems = {}}
      for _, id in ipairs(ids) do
        local pok, perr = patch_item(txc, root, id)
        if not pok then
          return false, perr
        end
      end
      return true, ""
    end)
  if not tok then
    local _c, _cerr = cachedb.close(c)
    return false, terr
  end
  local fresh, ferr = cachedb.fresh_digest(root)
  if fresh == nil then
    local _c, _cerr = cachedb.close(c)
    return false, ferr
  end
  local mok, merr = cachedb.meta_set(db, "refs_digest", fresh)
  local _c, cerr = cachedb.close(c)
  if not mok then
    return false, merr
  end
  return true, cerr
end

--- The pre-write half of the incremental save path: a fresh digest of
--- the board's ref state right now, before anything moves — nil when
--- there is no cache file to patch (a cold clone, one `rebuild`
--- already claimed) or the digest could not be read, either of which
--- means `after_save` should do nothing. Call this BEFORE the write
--- that follows; its result is the proof the cache was valid
--- immediately beforehand, which is what makes patching only the
--- touched ids safe rather than silently trusting a maybe-stale file.
--- @param root string The store's root
--- @return string | nil The pre-write digest
local function guard(root: string): string | nil
  if not fs.is_file(cachedb.path_of(root)) then
    return nil
  end
  local d = cachedb.fresh_digest(root)
  return d
end

--- The post-write half: patch exactly the ids a save touched, but
--- only when `guard`'s digest still matches what the cache file has
--- recorded — proof nothing else moved a ref out from under it
--- between the guard and this call. A mismatch (or a nil guard) is
--- silently skipped: the cache is left exactly as it was, stale or
--- absent, for the next `open` to rebuild. Errors are swallowed the
--- same way — this is a speed-up, never a contract the write's own
--- success depends on.
--- @param root string The store's root
--- @param before_digest string | nil `guard`'s result, from before the write
--- @param touched_ids {string} Every item id the write touched
local function after_save(root: string, before_digest: string | nil, touched_ids: {string})
  if before_digest == nil then
    return
  end
  local path = cachedb.path_of(root)
  if not fs.is_file(path) then
    return
  end
  local db = sqlite.open(path, {wal = false})
  if db == nil then
    return
  end
  local stored = cachedb.meta_get(db, "refs_digest")
  local uv = cachedb.db_user_version(db)
  local _c, _cerr = db:close()
  if uv ~= SCHEMA_VERSION or stored ~= before_digest then
    return
  end
  local _ok, _err = apply_patch(root, touched_ids)
end

--- Wrap a fetch (`_work.publish.sync`'s, or the lost-race recovery's)
--- with the cache's incremental update: a `for-each-ref` snapshot
--- before, the fetch itself, a snapshot after, and — only when the
--- cache was valid immediately before (its stored digest matches the
--- BEFORE snapshot's) — a patch of every id whose sha changed,
--- appeared, or disappeared. The fetch's own result passes through
--- unchanged either way; a cache that cannot be read, or was already
--- stale, is left for the next `open` to rebuild, never a reason to
--- fail the fetch.
--- @param root string The store's root
--- @param fetch_fn function() -> boolean, string  The fetch to run
--- @return boolean True on success
--- @return string Error message
local function around_fetch(root: string, fetch_fn: function(): boolean, string): boolean, string
  local path = cachedb.path_of(root)
  local before_entries: {refs.RefEntry} | nil = nil
  if fs.is_file(path) then
    before_entries = cachedb.refs_snapshot(root)
  end
  local ok, err = fetch_fn()
  if not ok or before_entries == nil then
    return ok, err
  end
  local after_entries = cachedb.refs_snapshot(root)
  if after_entries == nil then
    return ok, err
  end
  local touched = cachedb.changed_ids(cachedb.shas_by_item(before_entries),
    cachedb.shas_by_item(after_entries))
  if #touched == 0 then
    return ok, err
  end
  after_save(root, cachedb.digest_of(before_entries), touched)
  return ok, err
end

local record cache
  type Cache = Cache
  SCHEMA_VERSION: integer
  path_of: function(root: string): string
  open: function(root: string): Cache | nil, string
  rebuild: function(root: string): Cache | nil, string
  close: function(c: Cache): boolean, string
  guard: function(root: string): string | nil
  after_save: function(root: string, before_digest: string | nil, touched_ids: {string})
  around_fetch: function(root: string,
  fetch_fn: function(): boolean, string): boolean, string
end

local M: cache = {
  SCHEMA_VERSION = SCHEMA_VERSION,
  path_of = cachedb.path_of,
  open = open,
  rebuild = rebuild,
  close = cachedb.close,
  guard = guard,
  after_save = after_save,
  around_fetch = around_fetch,
}

return M
