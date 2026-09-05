--- The board's persistent, incrementally maintained SQLite mirror:
--- one file, `o/board.db` under a checkout's own store root, carrying
--- `_work.index`'s schema plus `_work.find`'s search table, a `lanes`
--- table, and a `cache_meta` table recording which ref state and
--- schema shape the file reflects (`_work.cachedb`, this module's
--- low-level half, including the WAL/`synchronous` rule every
--- connection here opens under). It is DERIVED and never truth —
--- gitignored, rebuilt whenever it is missing, mismatched, or behind
--- the refs it mirrors — but unlike `_work.index`'s own `:memory:`
--- connection, it survives one verb invocation to the next, so a
--- session's second `find` (or `sync`'s lane read, or `new`'s
--- duplicate check — `_work.cachequery`, built on top of this module)
--- costs a handful of small queries against an already-open file
--- rather than a fresh whole-board read.
---
--- `open` is the guard every reader goes through: a fresh
--- `for-each-ref` digest over `refs/heads/items`, `refs/heads/ended` and
--- `refs/heads/board`, plus the schema fingerprint, compared against
--- what the file last recorded, decides reuse or a cold `rebuild` —
--- and a file that fails to validate for ANY reason (a genuine SQLite
--- error included, not only a digest or version mismatch) is wiped
--- and rebuilt exactly once, the same way. `guard`/`after_save` and
--- `around_fetch` are the incremental half: a mutation or a fetch that
--- moves refs patches exactly the items whose refs moved, rather than
--- paying for `rebuild`'s whole-board read on every write. The save
--- path patches straight from what the caller already holds in
--- memory — the just-written items, and the one spec body that may
--- have changed — never re-reading git; only the fetch path re-reads,
--- since a fetch can land a version nobody observed directly, and it
--- does so in one batch (`_work.gitreadmany.load_many`) rather than
--- one read per id. Deliberately built on `root: string` rather than
--- `_work.store`'s `Store`: `_work.store` has no need of this module
--- at all, and it is `_work.gitgate`'s `commit_and_publish` (which already requires
--- `_work.store`) that calls `guard`/`after_save` around every
--- mutation's `store.save`, and `_work.publish` that wraps its fetches
--- with `around_fetch` — a `Store` dependency here would close a cycle
--- against both.
local cachedb = require("_work.cachedb")
local cacherebuild = require("_work.cacherebuild")
local cachewatch = require("_work.cachewatch")
local events = require("_work.events")
local find = require("_work.find")
local fs = require("cosmic.fs")
local gitread = require("_work.gitread")
local gitreadmany = require("_work.gitreadmany")
local index = require("_work.index")
local item = require("_work.item")
local refs = require("_work.refs")
local sqlite = require("cosmic.sqlite")

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
local function open(root: string, known_digest?: string): Cache | nil, string
  local path = cachedb.path_of(root)
  if fs.is_file(path) then
    local db = cachedb.open_conn(path)
    if db ~= nil then
      local fresh = known_digest
      if fresh == nil then
        fresh = cachedb.fresh_digest(root)
      end
      local expected_fp = cachedb.expected_schema_fingerprint()
      if fresh ~= nil and cachedb.db_user_version(db) == SCHEMA_VERSION
      and cachedb.meta_get(db, "refs_digest") == fresh
      and expected_fp ~= nil and cachedb.meta_get(db, "schema_fingerprint") == expected_fp then
        return {db = db, specs = {}, load_problems = {}}
      end
      local _c, _cerr = db:close()
    end
  end
  cachedb.wipe(root)
  return rebuild(root)
end

--- On any error patching an already-open cache — a genuine SQLite
--- failure, not an ordinary staleness this same call already screens
--- for — wipe the file and rebuild once: `rebuild` reads straight from
--- git, which by this point already carries whatever the save or
--- fetch just landed, so a clean rebuild is a correct answer on its
--- own, not merely a fallback. A second failure is returned as-is.
--- @param root string The store's root
--- @param cause string What the patch itself failed with, for the message
--- @return boolean True once the rebuild lands
--- @return string Error message
local function heal(root: string, cause: string): boolean, string
  cachedb.wipe(root)
  local rebuilt, rerr = rebuild(root)
  if rebuilt == nil then
    return false, ("cache patch failed (%s), and the rebuild that followed "
      .. "also failed: %s"):format(cause, rerr)
  end
  local _c, _cerr = cachedb.close(rebuilt)
  return true, ""
end

--- The shared body of a save's and a fetch's incremental update: open
--- the file (skipping quietly when there is none, or it cannot even be
--- opened — `open`'s problem to rebuild next time, never this write's
--- to fail over), confirm `before_digest` still matches what it has
--- recorded (proof nothing else moved a ref out from under it since
--- the caller took that snapshot), run `apply_fn` in one transaction,
--- then record the post-write ref state — `after_entries`, when the
--- caller already took that snapshot (a fetch's own post-fetch read),
--- one more `refs_snapshot` when not (a save has no such snapshot to
--- reuse) — as `cache_meta`'s `refs_digest` and `seq_sha` both, so
--- either path keeps `refs/heads/board/seq`'s own recorded tip current
--- with no extra read of its own. Any real failure along the way heals
--- (`heal`) rather than leaving the file silently stale.
--- @param root string The store's root
--- @param before_digest string | nil The pre-write digest
--- @param after_entries {refs.RefEntry} | nil The post-write ref
--- listing, when the caller already took it; nil to read one fresh
--- @param apply_fn function(tx) Patches exactly the touched rows
--- @return boolean True on success (including nothing to do)
--- @return string Error message
local function apply_patch(root: string, before_digest: string | nil,
    after_entries: {refs.RefEntry} | nil,
    apply_fn: function(sqlite.Database): boolean, string): boolean, string
  if before_digest == nil then
    return true, ""
  end
  local path = cachedb.path_of(root)
  if not fs.is_file(path) then
    return true, ""
  end
  local db = cachedb.open_conn(path)
  if db == nil then
    return true, ""
  end
  local stored = cachedb.meta_get(db, "refs_digest")
  local uv = cachedb.db_user_version(db)
  if uv ~= SCHEMA_VERSION or stored ~= before_digest then
    local _c, _cerr = db:close()
    return true, ""
  end
  local tok, terr = db:transaction(apply_fn)
  if not tok then
    local _c, _cerr = db:close()
    return heal(root, terr)
  end
  local entries = after_entries
  if entries == nil then
    local fresh_entries, ferr = cachedb.refs_snapshot(root)
    if fresh_entries == nil then
      local _c, _cerr = db:close()
      return heal(root, ferr)
    end
    entries = fresh_entries
  end
  local mok, merr = cachedb.meta_set(db, "refs_digest", cachedb.digest_of(entries))
  if mok then
    mok, merr = cachedb.meta_set(db, "seq_sha", cachewatch.seq_sha_of(entries))
  end
  if not mok then
    local _c, _cerr = db:close()
    return heal(root, merr)
  end
  local cok, cerr = db:close()
  if not cok then
    return false, cerr
  end
  return true, ""
end

--- The pre-write half of the incremental save path: a fresh digest of
--- the board's ref state right now, before anything moves — nil when
--- there is no cache file to patch (a cold clone, one `rebuild`
--- already claimed) or the digest could not be read, either of which
--- means `after_save` should do nothing. Call this BEFORE the write
--- that follows; its result is the proof the cache was valid
--- immediately beforehand, which is what makes patching only the
--- touched items safe rather than silently trusting a maybe-stale file.
--- @param root string The store's root
--- @param known_digest string | nil A ref-snapshot digest the caller
--- already took (`_work.store.list`'s own `board_digest`, say) — skips
--- this guard's otherwise-fresh `for-each-ref` when given
--- @return string | nil The pre-write digest
local function guard(root: string, known_digest?: string): string | nil
  if not fs.is_file(cachedb.path_of(root)) then
    return nil
  end
  if known_digest ~= nil and known_digest ~= "" then
    return known_digest
  end
  local d = cachedb.fresh_digest(root)
  return d
end

--- The post-write half: patch every item a save touched straight from
--- what the caller holds — `items[1]` (`_work.gitgate.commit_and_publish`'s
--- `it`) first, then the rest (its `also`) — with no git read at all,
--- since the caller already has exactly what `store.save` just wrote.
--- `spec_body` replaces `items[1]`'s indexed spec text when the save
--- changed it, nil to leave it exactly as already indexed; `also`
--- items never carry a spec change, so this never asks about theirs.
--- Runs only when `guard`'s digest still matches what the cache file
--- has recorded — a mismatch (or a nil guard) is silently skipped: the
--- cache is left exactly as it was, stale or absent, for the next
--- `open` to rebuild.
--- `written` names the ids with a new commit; one absent still gets its
--- fields patched, just no `events` row and no lease change (its
--- ref/tip/touched_at carry forward exactly as already recorded — an
--- `also` item a mutation's diff found nothing to write for). `message`
--- is the shared subject.
--- A written id's ref is read straight off the row this same patch is
--- about to replace — an item's ref never changes once created — or,
--- for an id with no prior row at all (a brand-new item), defaults to
--- `refs/heads/items/<id>`: the only ref `_work.gitwrite` ever creates
--- one under. `touched_at`, and the `at` `events.apply_save` records,
--- are `written_at` — the epoch second the write stamped on every
--- commit it made — so the cache and the git log agree exactly; this
--- call's own clock is the fallback for a caller that has no write to
--- report.
--- @param root string The store's root
--- @param before_digest string | nil `guard`'s result, from before the write
--- @param items {item.Item} `it`, then every `also` item, in that order
--- @param spec_body string | nil `items[1]`'s replacement spec, nil to leave it alone
--- @param message string The commit subject this save wrote
--- @param written {string: string} Item id -> new sha, for ids that got a new commit
local function after_save(root: string, before_digest: string | nil,
    items: {item.Item}, spec_body: string | nil, message: string,
    written: {string: string}, written_at?: integer)
  if #items == 0 then
    return
  end
  local now = written_at or os.time()
  local _ok, _err = apply_patch(root, before_digest, nil,
    function(tx: sqlite.Database): boolean, string
      local txc: Cache = {db = tx, specs = {}, load_problems = {}}
      for i, it in ipairs(items) do
        local body: string | nil = nil
        if i == 1 then
          body = spec_body
        end
        local new_sha = written[it.id]
        local lease: index.Lease | nil = nil
        if new_sha ~= nil and new_sha ~= "" then
          local prior = tx:query_one("SELECT ref FROM items WHERE id = ?", {it.id})
          local ref = "refs/heads/items/" .. it.id
          if prior ~= nil then
            ref = prior.ref as string -- cast: from any (sqlite row)
          end
          lease = {ref = ref, tip = new_sha, touched_at = now}
        end
        local pok, perr = cachedb.patch_item(txc, it, body, lease)
        if not pok then
          return false, perr
        end
        if new_sha ~= nil and new_sha ~= "" then
          local eok, eerr = events.apply_save(tx, it.id, new_sha, now, message)
          if not eok then
            return false, eerr
          end
        end
      end
      return true, ""
    end)
end

--- The fetch path's incremental update: read exactly `ids` fresh from
--- git, in one batch (`_work.gitreadmany.load_many`, plus one
--- `gitread.read_specs` for their sidecars) rather than one read per
--- id, then patch them — unlike the save path, a fetch can land a
--- version nobody observed directly, so this always rereads rather
--- than trusting anything already in memory. An id `load_many` did
--- not find is genuinely gone (a locally pruned ref), which is a
--- plain delete.
--- `old_shas` is each touched id's previous sha (absent when new) —
--- `events.apply_fetch`'s `old..new`. `after_entries` is the fetch's
--- own post-fetch ref listing (`around_fetch`'s own snapshot) — where
--- every patched id's committer date is read from (`_work.cachewatch.touched_by_item`),
--- with no further git read of its own.
--- @param root string The store's root
--- @param before_digest string | nil The pre-fetch digest
--- @param after_entries {refs.RefEntry} The post-fetch ref listing, already taken
--- @param ids {string} Every item id whose sha changed, appeared, or disappeared
--- @param old_shas {string: string} Each touched id's previously observed sha
--- @return boolean True on success (including nothing to do)
--- @return string Error message
local function patch_fetched(root: string, before_digest: string | nil,
    after_entries: {refs.RefEntry}, ids: {string}, old_shas: {string: string}): boolean, string
  if #ids == 0 then
    return true, ""
  end
  local loaded, lerr = gitreadmany.load_many(root, ids)
  if loaded == nil then
    return false, lerr
  end
  local shas: {string: string} = {}
  for id, l in pairs(loaded) do
    shas[id] = l.sha
  end
  local specs = gitread.read_specs(root, shas, ids)
  local touched_at = cachewatch.touched_by_item(after_entries)
  return apply_patch(root, before_digest, after_entries,
    function(tx: sqlite.Database): boolean, string
      local txc: Cache = {db = tx, specs = {}, load_problems = {}}
      for _, id in ipairs(ids) do
        local l = loaded[id]
        if l == nil then
          local dok, derr = index.delete_item(tx, id)
          if not dok then
            return false, derr
          end
          local rok, rerr = find.remove_item(txc, id)
          if not rok then
            return false, rerr
          end
        else
          local lease: index.Lease = {ref = l.ref, tip = l.sha,
            touched_at = touched_at[id] or 0}
          local pok, perr = cachedb.patch_item(txc, l.it, specs[id] or "", lease)
          if not pok then
            return false, perr
          end
          local eok, eerr = events.apply_fetch(tx, root, id, old_shas[id] or "", l.sha)
          if not eok then
            return false, eerr
          end
        end
      end
      return true, ""
    end)
end

--- Wrap a fetch (`_work.publish.sync`'s, or the lost-race recovery's)
--- with the cache's incremental update: a `for-each-ref` snapshot
--- before, the fetch itself, a snapshot after, and — only when the
--- cache was valid immediately before (its stored digest matches the
--- BEFORE snapshot's) — a batched patch (`patch_fetched`) of every id
--- whose sha changed, appeared, or disappeared. The fetch's own result
--- passes through unchanged either way; a cache that cannot be read,
--- or was already stale, is left for the next `open` to rebuild, never
--- a reason to fail the fetch. The board's own outcome ranking needs no
--- special case here: it is the board item's own `.order` field, so a
--- change to it moves the board item's sha, and `changed_ids` (below)
--- already patches whatever item id moved.
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
  local before_shas = cachedb.shas_by_item(before_entries)
  local touched = cachedb.changed_ids(before_shas, cachedb.shas_by_item(after_entries))
  if #touched == 0 then
    return ok, err
  end
  local _ok2, _err2 = patch_fetched(root, cachedb.digest_of(before_entries),
    after_entries, touched, before_shas)
  return ok, err
end

local record cache
  type Cache = Cache
  SCHEMA_VERSION: integer
  path_of: function(root: string): string
  open: function(root: string, known_digest?: string): Cache | nil, string
  rebuild: function(root: string): Cache | nil, string
  close: function(c: Cache): boolean, string
  guard: function(root: string, known_digest?: string): string | nil
  after_save: function(root: string, before_digest: string | nil,
  items: {item.Item}, spec_body: string | nil, message: string,
  written: {string: string}, written_at?: integer)
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
