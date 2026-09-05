--- The board cache's read-side convenience wrappers, built on
--- `_work.cache`'s guarded `open`: the scheduled-lane observation
--- `_work.lanes` now reads and writes here instead of committing
--- `refs/heads/board/lanes`, and the whole open/query/close cycle behind
--- `new`'s pre-mint duplicate check and the `find` verb. Split out of
--- `_work.cache` so that module (the guard, `rebuild`, and the
--- incremental save/fetch paths) stays under the repo's line cap.
local cache = require("_work.cache")
local cachedb = require("_work.cachedb")
local find = require("_work.find")
local fs = require("cosmic.fs")
local sqlite = require("cosmic.sqlite")
local tail = require("_work.tail")

--- Every observed lane's last recorded conclusion, "" for a lane never
--- recorded — `_work.lanes`' `read_state`, backed by the cache's
--- `lanes` table instead of the committed `refs/heads/board/lanes`. A board
--- that has never synced (no cache file, or one `open` cannot even
--- build) has no observation, matching the ref-based behavior it
--- replaces.
--- @param root string The store's root
--- @param known_digest string | nil A ref-snapshot digest the caller
--- already took, passed straight through to `cache.open`
--- @return {string: string} Conclusion by workflow filename
local function lanes_read(root: string, known_digest?: string): {string: string}
  local c, _err = cache.open(root, known_digest)
  if c == nil then
    return {}
  end
  local out: {string: string} = {}
  for row in assert(c.db:query("SELECT workflow, conclusion FROM lanes")) do
    out[row.workflow as string] = row.conclusion as string -- cast: from any (sqlite row)
  end
  local _ok, _cerr = cache.close(c)
  return out
end

--- Record each lane's observed conclusion, replacing whatever this
--- checkout last recorded for it — `_work.lanes`' `record`, one row
--- per lane in the cache's `lanes` table rather than a whole-board
--- commit. LOCAL, per-clone state now: never pushed, and never shared
--- with another checkout the way the committed ref used to be.
--- @param root string The store's root
--- @param facts {string: string} One conclusion per lane
--- @param known_digest string | nil A ref-snapshot digest the caller
--- already took, passed straight through to `cache.open`
--- @return boolean True on success
--- @return string Error message
local function lanes_write(root: string, facts: {string: string},
    known_digest?: string): boolean, string
  local c, err = cache.open(root, known_digest)
  if c == nil then
    return false, err
  end
  local now = os.time()
  local ok, terr = c.db:transaction(function(tx: sqlite.Database): boolean, string
      for workflow, conclusion in pairs(facts) do
        local wok, werr = tx:exec([[
          INSERT INTO lanes(workflow, conclusion, observed_at) VALUES (?, ?, ?)
          ON CONFLICT(workflow) DO UPDATE SET conclusion = excluded.conclusion,
            observed_at = excluded.observed_at
        ]], {workflow, conclusion, now})
        if not wok then
          return false, werr
        end
      end
      return true, ""
    end)
  local closed_ok, cerr = cache.close(c)
  if not ok then
    return false, terr
  end
  if not closed_ok then
    return false, cerr
  end
  return true, ""
end

--- `_work.find.similar`'s hits as `new`'s pre-mint warning lines: open
--- (rebuilding when stale), query, close. Infallible by design — a
--- warning, never a refusal — so a failure anywhere (an empty board, a
--- cache that could not be opened or rebuilt) simply means no lines to
--- print, the same as a title with nothing similar on the board.
--- @param root string The store's root
--- @param title string The candidate title
--- @return {string} "similar: «handle» title" lines, at most three, possibly none
local function similar_lines(root: string, title: string): {string}
  local c, _err = cache.open(root)
  if c == nil then
    return {}
  end
  local hits = find.similar(c, title)
  local _ok, _cerr = cache.close(c)
  local out: {string} = {}
  for _, h in ipairs(hits or {}) do
    out[#out + 1] = ("similar: %s %s"):format(tail.handle(h.id), h.title)
  end
  return out
end

--- A handle's tail resolved straight against the cache file, with
--- none of `_work.cache.open`'s freshness guard: ids are immutable, so
--- a hit is exact even when the file is stale for some OTHER reason —
--- an item newer than the file simply misses, and the caller falls
--- through to `_work.tail.resolve_glob` exactly as an absent cache
--- does. Opens the file directly (no rebuild, no digest check), so a
--- hit costs no process at all; a missing file, an unreadable one, or
--- a query failure all return the same "fall through" answer as a
--- miss — only two or more hits are reported back as a refusal.
--- @param root string The store's root
--- @param input string What a session typed
--- @return string | nil The resolved id; nil either to fall through or to refuse
--- @return string "" to fall through; an ambiguity message to refuse
local function resolve_tail(root: string, input: string): string | nil, string
  local path = cachedb.path_of(root)
  if not fs.is_file(path) then
    return nil, ""
  end
  local db, _err = cachedb.open_conn(path)
  if db == nil then
    return nil, ""
  end
  local rows, _qerr = db:query(
    "SELECT id FROM items WHERE lower(id) LIKE '%' || lower(?)", {tail.normalize(input)})
  if rows == nil then
    local _c, _cerr = db:close()
    return nil, ""
  end
  local ids: {string} = {}
  for row in rows do
    ids[#ids + 1] = row.id as string -- cast: from any (sqlite row)
  end
  local ierr = rows:err()
  local _c, _cerr = db:close()
  if ierr or #ids == 0 then
    return nil, ""
  end
  if #ids == 1 then
    return ids[1], ""
  end
  local tails: {string} = {}
  for _, id in ipairs(ids) do
    tails[#tails + 1] = id:sub(20)
  end
  return nil, ("%s is ambiguous: %s"):format(input, table.concat(tails, " "))
end

--- `find TEXT...`: every hit for the joined query, ranked, one line
--- each — handle, state, title, snippet — then the verdict line
--- `gitboard-find: N hit(s)`. Opens the cache (rebuilding it when
--- stale), queries, and closes.
--- @param root string The store's root
--- @param text string The query text
--- @return integer Exit code
local function cmd_find(root: string, text: string): integer
  local c, err = cache.open(root)
  if c == nil then
    print(("gitboard-find: %s"):format(err))
    return 1
  end
  local hits, qerr = find.query(c, text, 20)
  local _ok, _cerr = cache.close(c)
  if hits == nil then
    print(("gitboard-find: %s"):format(qerr))
    return 1
  end
  for _, h in ipairs(hits) do
    print(("%s [%s] %s — %s"):format(tail.handle(h.id), h.state, h.title,
        h.snippet))
  end
  print(("gitboard-find: %d hit(s)"):format(#hits))
  return 0
end

local record cachequery
  lanes_read: function(root: string, known_digest?: string): {string: string}
  lanes_write: function(root: string, facts: {string: string},
  known_digest?: string): boolean, string
  similar_lines: function(root: string, title: string): {string}
  resolve_tail: function(root: string, input: string): string | nil, string
  cmd_find: function(root: string, text: string): integer
end

local M: cachequery = {
  lanes_read = lanes_read,
  lanes_write = lanes_write,
  similar_lines = similar_lines,
  resolve_tail = resolve_tail,
  cmd_find = cmd_find,
}

return M
