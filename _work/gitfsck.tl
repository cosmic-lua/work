--- Offline native-board audit: validate the tree and claims, rebuild a disposable
--- query projection, and compare structure, item rows and attributed history.
--- Archived format-5 refs are migration evidence and do not affect this audit.
local cacherebuild = require("_work.cacherebuild")
local dependsfsck = require("_work.gitfsck_depends")
local gate = require("_work.gitgate")
local stateread_fsck = require("_work.stateread_fsck")
local gitread = require("_work.gitread")
local index = require("_work.index")
local read = require("_work.read")
local sqlite = require("cosmic.sqlite")
local spec = require("_work.spec")
local store = require("_work.store")
local tail = require("_work.tail")

--- `items` columns worth comparing between the session's cache and the
--- throwaway rebuild — every column but `id` itself, which is the key
--- the comparison is keyed on.
local ITEM_COLUMNS < const >: {string} = {
  "title", "parent", "repo", "base", "claim", "reviewer", "pr",
  "result", "verdict", "verdict_head", "resolution",
  "ref", "tip", "touched_at",
}

--- Every `items` row, keyed by id, every column but `id` stringified —
--- the shape `audit_cache` diffs.
--- @param db sqlite.Database The connection
--- @return {string: {string: string}} | nil id -> column -> value
--- @return string Error message
local function read_items(db: sqlite.Database): {string: {string: string}} | nil, string
  local rows, err = db:query("SELECT * FROM items")
  if rows == nil then
    return nil, err
  end
  local out: {string: {string: string}} = {}
  for row in rows do
    local id = row.id as string -- cast: from any (sqlite row)
    local cols: {string: string} = {}
    for _, col in ipairs(ITEM_COLUMNS) do
      cols[col] = tostring(row[col])
    end
    out[id] = cols
  end
  local rerr = rows:err()
  if rerr then
    return nil, rerr
  end
  return out, ""
end

--- Every `ranks` row, grouped by parent, in stored position order —
--- the whole ordered child list is what `audit_cache` diffs, since the
--- ORDER is exactly the fact under audit.
--- @param db sqlite.Database The connection
--- @return {string: {string}} | nil parent -> ordered child ids
--- @return string Error message
local function read_ranks(db: sqlite.Database): {string: {string}} | nil, string
  local rows, err = db:query("SELECT parent, child FROM ranks ORDER BY parent, position")
  if rows == nil then
    return nil, err
  end
  local out: {string: {string}} = {}
  for row in rows do
    local parent = row.parent as string -- cast: from any (sqlite row)
    local child = row.child as string -- cast: from any (sqlite row)
    out[parent] = out[parent] or {}
    local list = out[parent]
    list[#list + 1] = child
  end
  local rerr = rows:err()
  if rerr then
    return nil, rerr
  end
  return out, ""
end

--- Every item's `events` row count.
--- @param db sqlite.Database The connection
--- @return {string: integer} | nil item id -> row count
--- @return string Error message
local function read_event_counts(db: sqlite.Database): {string: integer} | nil, string
  local rows, err = db:query("SELECT item, COUNT(*) AS n FROM events GROUP BY item")
  if rows == nil then
    return nil, err
  end
  local out: {string: integer} = {}
  for row in rows do
    out[row.item as string] = math.tointeger(row.n as number) or 0 -- cast: from any (sqlite row)
  end
  local rerr = rows:err()
  if rerr then
    return nil, rerr
  end
  return out, ""
end

--- The audit `fsck` exists to run: every `items` row (lease columns
--- included), every `ranks` row, and the `events` count per item,
--- between the throwaway rebuild (`refs_db`, freshly filled from what
--- git says right now) and the session's own open cache (`cache_db`,
--- `o/board.db`). One finding line per disagreement,
--- `cache: <handle> <column> reads X, refs say Y` — named for the
--- cache since the refs are truth and the cache is the read model
--- derived from them.
--- @param refs_db sqlite.Database The throwaway rebuild
--- @param cache_db sqlite.Database The session's open cache
--- @return {string} One line per disagreement
--- @return string Error message
local function audit_cache(refs_db: sqlite.Database, cache_db: sqlite.Database): {string}, string
  local refs_items, rierr = read_items(refs_db)
  if refs_items == nil then
    return {}, rierr
  end
  local cache_items, cierr = read_items(cache_db)
  if cache_items == nil then
    return {}, cierr
  end
  local refs_ranks, rrerr = read_ranks(refs_db)
  if refs_ranks == nil then
    return {}, rrerr
  end
  local cache_ranks, crerr = read_ranks(cache_db)
  if cache_ranks == nil then
    return {}, crerr
  end
  local refs_events, reerr = read_event_counts(refs_db)
  if refs_events == nil then
    return {}, reerr
  end
  local cache_events, ceerr = read_event_counts(cache_db)
  if cache_events == nil then
    return {}, ceerr
  end

  local ids: {string} = {}
  local seen: {string: boolean} = {}
  for id in pairs(refs_items) do
    seen[id] = true
    ids[#ids + 1] = id
  end
  for id in pairs(cache_items) do
    if not seen[id] then
      seen[id] = true
      ids[#ids + 1] = id
    end
  end
  table.sort(ids)

  local out: {string} = {}
  for _, id in ipairs(ids) do
    local want = refs_items[id]
    local got = cache_items[id]
    if want == nil then
      out[#out + 1] = ("cache: %s is in the cache but not in the refs"):format(tail.handle(id))
    elseif got == nil then
      out[#out + 1] = ("cache: %s is in the refs but not in the cache"):format(tail.handle(id))
    else
      for _, col in ipairs(ITEM_COLUMNS) do
        if got[col] ~= want[col] then
          out[#out + 1] = ("cache: %s %s reads %s, refs say %s"):format(
            tail.handle(id), col, got[col], want[col])
        end
      end
    end
    local want_n = refs_events[id] or 0
    local got_n = cache_events[id] or 0
    if want_n ~= got_n then
      out[#out + 1] = ("cache: %s events reads %d, refs say %d"):format(
        tail.handle(id), got_n, want_n)
    end
    local want_order = table.concat(refs_ranks[id] or {}, ",")
    local got_order = table.concat(cache_ranks[id] or {}, ",")
    if want_order ~= got_order then
      out[#out + 1] = ("cache: %s order reads [%s], refs say [%s]"):format(
        tail.handle(id), got_order, want_order)
    end
  end
  return out, ""
end

--- The `ok` verdict detail: item count alone when nothing was ignored,
--- with the stale-order count appended only when there is one — the
--- common healthy-board case stays exactly as terse as it always was.
--- @param n_items integer How many items the board carries
--- @param n_stale integer How many stale order entries were found
--- @return string
local function ok_detail(n_items: integer, n_stale: integer): string
  if n_stale > 0 then
    return ("ok (%d items), %d stale order entries"):format(n_items, n_stale)
  end
  return ("ok (%d items)"):format(n_items)
end

--- The failing verdict detail: the problem count, with the stale-order
--- count appended only when there is one.
--- @param n_problems integer How many real problems were found
--- @param n_stale integer How many stale order entries were found
--- @return string
local function fail_detail(n_problems: integer, n_stale: integer): string
  if n_stale > 0 then
    return ("%d problem(s), %d stale order entries"):format(n_problems, n_stale)
  end
  return ("%d problem(s)"):format(n_problems)
end

local function cmd_fsck(s: store.Store): integer
  local claim_problems = stateread_fsck.problems(s.root, s.state_head)
  -- A fresh git read, never the cache-backed `store.list`: this audit's
  -- own job is checking the database against git, so it needs to
  -- rebuild the derived rows from the refs itself rather than trust
  -- whatever `o/board.db` already holds.
  local board, lerr = gitread.list(s.root)
  if board == nil then
    for _, p in ipairs(claim_problems) do print(p) end
    print(lerr)
    return gate.verdict_line("fsck", false, ("%d problem(s)")
      :format(#claim_problems + 1))
  end
  local all = board.items
  for id, sha in pairs(board.shas_by_id) do
    s.leased_sha[id] = sha
  end
  local ids: {string} = {}
  local observed_shas: {string} = {}
  for _, it in ipairs(all) do
    ids[#ids + 1] = it.id
    local sha = s.leased_sha[it.id]
    if sha ~= nil and sha ~= "" then
      observed_shas[#observed_shas + 1] = sha
    end
  end
  local specs = store.read_specs(s, ids)
  -- The throwaway rebuild indexes one searchable text per item, where
  -- the round trip below wants the record the tree actually holds.
  local spec_texts: {string: string} = {}
  for id, sp in pairs(specs) do
    spec_texts[id] = spec.document(sp)
  end

  local problems: {string} = {}
  local stale_orders: {string} = {}
  for _, p in ipairs(claim_problems) do
    problems[#problems + 1] = p
  end

  -- Rebuild the derived rows from the refs into a throwaway in-memory
  -- database, reusing `_work.cacherebuild`'s own fill path — the same
  -- schema and data `store.read` incrementally maintains at
  -- `o/board.db`, built fresh from what git says right now.
  local mem, merr = sqlite.open(":memory:")
  if mem == nil then
    problems[#problems + 1] = ("could not open a throwaway database: %s"):format(merr)
  else
    local fok, ferr = cacherebuild.fill(mem, s.root, board, spec_texts)
    if not fok then
      problems[#problems + 1] = ("could not rebuild the throwaway database: %s"):format(ferr)
      local _c, _cerr = mem:close()
      mem = nil
    end
  end

  if mem ~= nil then
    local rebuilt: index.Index = {db = mem, specs = spec_texts, load_problems = {}}
    -- `read.structure`'s four SQL-derivable findings, asked of the
    -- fresh rebuild — what a Teal walk over `all` used to compute by
    -- hand. `stale_order` is reported but never counted: a read that
    -- walks `_work.read.children` skips straight past it, so it is
    -- not a problem any read ever meets.
    local srows, serr = read.structure(rebuilt)
    if srows == nil then
      problems[#problems + 1] = ("could not query structure: %s"):format(serr)
    else
      for _, r in ipairs(srows) do
        local line = ("%s: %s"):format(r.id:sub(1, 8), r.detail)
        if r.kind == "stale_order" then
          stale_orders[#stale_orders + 1] = line
        else
          problems[#problems + 1] = line
        end
      end
    end

    -- The audit itself: the session's own open cache, diffed against
    -- the fresh rebuild row by row — one line per disagreement, or a
    -- single confirming line when there is none.
    local c, cerr = store.read(s)
    if c == nil then
      problems[#problems + 1] = ("could not open the session cache: %s"):format(cerr)
    else
      local diffs, derr = audit_cache(mem, c.db)
      if derr ~= "" then
        problems[#problems + 1] = ("could not audit the cache: %s"):format(derr)
      elseif #diffs == 0 then
        print("gitboard-fsck: cache agrees with the refs")
      end
      for _, d in ipairs(diffs) do
        problems[#problems + 1] = d
      end
    end
    local _c, _cerr = mem:close()
  end

  for _, p in ipairs(dependsfsck.problems(all, specs)) do
    problems[#problems + 1] = p
  end
  for _, p in ipairs(problems) do
    print(p)
  end
  if #stale_orders > 0 then
    print("stale order entries (ignored by reads):")
    for _, p in ipairs(stale_orders) do
      print(p)
    end
  end
  if #problems == 0 then
    return gate.verdict_line("fsck", true, ok_detail(#all, #stale_orders))
  end
  return gate.verdict_line("fsck", false, fail_detail(#problems, #stale_orders))
end

local record gitfsck
  cmd_fsck: function(s: store.Store): integer
end

local M: gitfsck = {
  cmd_fsck = cmd_fsck,
}

return M
