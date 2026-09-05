--- `_work.cache`'s cold-build path, split out to keep that module under
--- its line cap: every item and spec the board carries,
--- `_work.index`'s tables (including its `ranks` rows — each item's
--- own children from `insert_item`, the board item's own outcome
--- ranking included, since it is an ordinary `.order` field like any
--- other item's), `_work.find`'s search table, `cache_meta` and
--- `lanes` — written to a
--- temp file beside the real path and renamed into place once
--- complete, so a reader never sees a half-built file. The temp
--- connection is dropped out of WAL (`journal_mode = DELETE`, which
--- checkpoints and removes its `-wal`/`-shm` sidecars) before the
--- rename, so nothing named after the temp path is left behind; the
--- reopened final connection returns to `_work.cachedb`'s ordinary WAL
--- rule (`open_conn`). `_work.cache.rebuild` is this module's `rebuild`
--- re-exported unchanged — every caller still goes through there.
local cachedb = require("_work.cachedb")
local events = require("_work.events")
local find = require("_work.find")
local fs = require("cosmic.fs")
local gitread = require("_work.gitread")
local index = require("_work.index")
local index_rank = require("_work.index_rank")
local proc = require("cosmic.proc")
local readddl = require("_work.readddl")
local sqlite = require("cosmic.sqlite")

local type Cache = cachedb.Cache
local SCHEMA_VERSION < const > = cachedb.SCHEMA_VERSION

--- Cold-build the cache file from scratch. Exported for the equality
--- ratchet, which forces one to compare against the incrementally
--- maintained file; ordinary reads go through `_work.cache.open`.
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
  for _, p in ipairs({tmp_path, tmp_path .. "-wal", tmp_path .. "-shm"}) do
    if fs.is_present(p) then
      local rm_ok, rm_err = fs.remove(p)
      if not rm_ok then
        return nil, rm_err
      end
    end
  end
  local db, derr = cachedb.open_conn(tmp_path)
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
        local lease: index.Lease = {
          ref = board.refs_by_id[it.id] or "",
          tip = board.shas_by_id[it.id] or "",
          touched_at = board.touched_by_id[it.id] or 0,
        }
        local iok, ierr = index.insert_item(tx, it, lease)
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
  -- `_work.read`'s derived views, added here so every persisted cache
  -- file carries them — `_work.index_rank`'s `dense_rank`/`rank_path`
  -- first, since `_work.readddl`'s own views join against those.
  local irok, irerr = index_rank.ensure_views(c)
  if not irok then
    local _c, _cerr = db:close()
    return nil, irerr
  end
  local rdok, rderr = readddl.ensure_views(c)
  if not rdok then
    local _c, _cerr = db:close()
    return nil, rderr
  end
  local evok, everr = events.fill_rebuild(db, root, board.shas_by_id)
  if not evok then
    local _c, _cerr = db:close()
    return nil, everr
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
  local fp, fperr = cachedb.schema_fingerprint(db)
  if fp == nil then
    local _c, _cerr = db:close()
    return nil, fperr
  end
  local sok, serr = cachedb.meta_set(db, "refs_digest", digest)
  if sok then
    sok, serr = cachedb.meta_set(db, "schema_version", tostring(SCHEMA_VERSION))
  end
  if sok then
    sok, serr = cachedb.meta_set(db, "schema_fingerprint", fp)
  end
  if sok then
    sok, serr = cachedb.meta_set(db, "seq_sha", board.seq_sha)
  end
  if not sok then
    local _c, _cerr = db:close()
    return nil, serr
  end
  local jok, jerr = db:exec("PRAGMA journal_mode = DELETE")
  if not jok then
    local _c, _cerr = db:close()
    return nil, jerr
  end
  local cok, cerr = db:close()
  if not cok then
    return nil, cerr
  end
  for _, p in ipairs({tmp_path .. "-wal", tmp_path .. "-shm",
      -- `final_path`'s OWN leftover sidecars, wiped here too: a rename
      -- only moves the one path it names, so a `-wal`/`-shm` pair left
      -- beside the file this is about to replace would sit there
      -- associated with the NEW file by name alone once the rename
      -- lands — sqlite would try to replay it on the next open, an
      -- open connection's own not-yet-checkpointed leftover from
      -- BEFORE this rebuild replacing an item's freshly written row
      -- with whatever that stale log still held.
      final_path .. "-wal", final_path .. "-shm"}) do
    if fs.is_present(p) then
      local _ok, _err = fs.remove(p)
    end
  end
  local mvok, mverr = fs.move(tmp_path, final_path)
  if not mvok then
    return nil, mverr
  end
  local reopened, roerr = cachedb.open_conn(final_path)
  if reopened == nil then
    return nil, roerr
  end
  return {db = reopened, specs = {}, load_problems = {}}
end

local record cacherebuild
  rebuild: function(root: string): Cache | nil, string
end

local M: cacherebuild = {
  rebuild = rebuild,
}

return M
