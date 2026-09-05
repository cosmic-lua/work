--- A derived, in-memory SQLite index over the loaded item list. `open`
--- rebuilds it fresh from `store.list`/`store.read_specs` on every
--- verb invocation — it is never truth, never written back, and never
--- committed to git; the ref layout (`_work.store` and the modules
--- beside it) is the only durable state the board has. `_work.find`
--- layers full-text search on top of the same connection;
--- `_work.index_rank` adds the position-list rank path. `_work.indexddl`
--- carries the DDL text itself, split out to keep this module under
--- its line cap — its own header states the house SQLite defaults
--- every table here follows.
local indexddl = require("_work.indexddl")
local item = require("_work.item")
local sqlite = require("cosmic.sqlite")

local type Item = item.Item

local DDL < const > = indexddl.DDL

--- The open connection plus the per-load problem strings `open`
--- collected while inserting; `problems` adds the live, queried
--- findings to these before returning.
local record Index
  db: sqlite.Database
  --- Spec markdown by item id, as handed to `open` — not stored in
  --- any table here; `_work.find` reads it straight off this field
  --- when it builds the search index, so a caller that already paid
  --- for one batched `store.read_specs` never pays for a second.
  specs: {string: string}
  load_problems: {string}
end

--- Insert one row, catching a constraint refusal instead of letting it
--- abort the surrounding transaction — the ABORT conflict resolution
--- SQLite applies by default to a failed statement already undoes only
--- that statement, so the caller need only decide what to do with the
--- message.
--- @param db sqlite.Database The connection
--- @param sql string The INSERT or UPDATE
--- @param params table Bound parameters (`cosmic.sqlite`'s `Params`:
--- a list binds `?`, a keyed table binds `:name`)
--- @param on_fail string | nil The problem line to record on failure;
--- nil to format one from the driver's own message
--- @param problems {string} Problem lines, appended to on failure
--- @param label string The item id blamed when `on_fail` is nil
--- @return boolean True on success
local function try(db: sqlite.Database, sql: string, params: table,
    on_fail: string | nil, problems: {string}, label: string): boolean
  local ok, err = db:exec(sql, params)
  if ok then
    return true
  end
  problems[#problems + 1] = on_fail or ("index: %s: %s"):format(label, err)
  return false
end

--- Every item's row, in ONE pass — `parent` carries no foreign key
--- (see the module header), so nothing here has to defer or repair a
--- dangling one: a bogus parent lands verbatim, and `dangling_parents`
--- reports it live, queried, exactly like a dangling edge is.
--- @param db sqlite.Database The connection
--- @param items {Item} Every item to load
--- @param problems {string} Problem lines, appended to on any refusal
local function load_items(db: sqlite.Database, items: {Item}, problems: {string})
  for _, it in ipairs(items) do
    local landed = try(db, [[
      INSERT INTO items(id, title, parent, repo, base, key, claim, reviewer,
        pr, result, verdict, verdict_head, verdict_spec, resolution)
      VALUES (:id, :title, :parent, :repo, :base, :key, :claim, :reviewer,
        :pr, :result, :verdict, :verdict_head, :verdict_spec, :resolution)
    ]], {
        id = it.id, title = it.title, parent = it.parent or "",
        repo = it.repo or "", base = it.base or "", key = it.key or "",
        claim = it.claim or "", reviewer = it.reviewer or "",
        pr = it.pr or 0, result = it.result or "", verdict = it.verdict or "",
        verdict_head = it.verdict_head or "", verdict_spec = it.verdict_spec or "",
        resolution = it.resolution or "",
      }, nil, problems, it.id)
    if landed then
      for seq, name in ipairs(it.builders or {}) do
        try(db, "INSERT OR IGNORE INTO builders(item, session, seq) VALUES (?, ?, ?)",
          {it.id, name, seq}, nil, problems, it.id)
      end
      for seq, name in ipairs(it.speccers or {}) do
        try(db, "INSERT OR IGNORE INTO speccers(item, session, seq) VALUES (?, ?, ?)",
          {it.id, name, seq}, nil, problems, it.id)
      end
      -- `it.order`'s own array index IS the stored 1-based position —
      -- a stale entry (naming something no longer a child of `it`)
      -- lands verbatim, exactly as the module header describes;
      -- `_work.index_rank`'s dense-position view is where a stale
      -- entry gets skipped.
      for pos, child in ipairs(it.order or {}) do
        try(db, "INSERT OR IGNORE INTO ranks(parent, position, child) VALUES (?, ?, ?)",
          {it.id, pos, child}, nil, problems, it.id)
      end
    end
  end
end

--- Open a fresh in-memory index over `items`, loading every row in one
--- transaction. A row a constraint refuses is skipped, not fatal: the
--- refusal is recorded (`Index.problems`) and the load continues, so a
--- flagged board still indexes.
--- @param items {Item} Every item, as `store.list` returns them
--- @param specs {string: string} | nil Spec markdown by id
--- (`store.read_specs`), retained for `_work.find` to reuse
--- @return Index | nil The index
--- @return string Error message: only a connection or DDL failure
local function open(items: {Item}, specs?: {string: string}): Index | nil, string
  local db, derr = sqlite.open(":memory:")
  if db == nil then
    return nil, derr
  end
  local fkok, fkerr = db:exec("PRAGMA foreign_keys = ON")
  if not fkok then
    local _ok, _cerr = db:close()
    return nil, fkerr
  end
  local ddlok, ddlerr = db:exec_script(DDL)
  if not ddlok then
    local _ok, _cerr = db:close()
    return nil, ddlerr
  end
  local problems: {string} = {}
  local txok, txerr = db:transaction(function(tx: sqlite.Database): boolean, string
      load_items(tx, items, problems)
      return true
    end)
  if not txok then
    local _ok, _cerr = db:close()
    return nil, txerr
  end
  return {db = db, specs = specs or {}, load_problems = problems}
end

--- Items sharing one non-empty key while both are open — always empty
--- given `one_open_item_per_key`'s unique index already refuses the
--- second such row at load; kept as a live, queried check on the
--- invariant rather than trusted to the index definition alone.
--- @param self Index The index
--- @return {string} Problem lines, possibly empty
local function key_duplicates(self: Index): {string}
  local out: {string} = {}
  for row in assert(self.db:query([[
      SELECT key, COUNT(*) AS n FROM open_items
      WHERE key <> '' GROUP BY key HAVING COUNT(*) > 1
    ]])) do
    out[#out + 1] = ("key %s is claimed by %d open items at once"):format(
      row.key, math.tointeger(row.n) or 0)
  end
  return out
end

--- Items whose `parent` names no row in `items` — a dangling parent,
--- queried live since the column carries no foreign key.
--- @param self Index The index
--- @return {string} Problem lines, possibly empty
local function dangling_parents(self: Index): {string}
  local out: {string} = {}
  for row in assert(self.db:query([[
      SELECT id, parent FROM items i
      WHERE i.parent <> ''
      AND NOT EXISTS (SELECT 1 FROM items p WHERE p.id = i.parent)
    ]])) do
    out[#out + 1] = ("%s: parent %s does not exist"):format(row.id, row.parent)
  end
  return out
end

--- Open items whose ancestor walk, bounded the same 16 hops
--- `_work.flow` uses, never reaches the board — a broken
--- or cyclic parent chain past the immediate parent, which the load's
--- own per-row check (a missing DIRECT parent) cannot see. A chain
--- that walks into a dangling parent id simply has no row to join
--- against and so never reaches a `parent = ''` row either — the same
--- outcome a genuinely cyclic chain gets, with no extra bookkeeping
--- needed to tell the two apart.
--- @param self Index The index
--- @return {string} Problem lines, possibly empty
local function broken_chains(self: Index): {string}
  local out: {string} = {}
  for row in assert(self.db:query([[
      WITH RECURSIVE chain(id, cur, depth) AS (
        SELECT id, id, 0 FROM open_items
        UNION ALL
        SELECT c.id, i.parent, c.depth + 1
        FROM chain c JOIN items i ON i.id = c.cur
        WHERE i.parent <> '' AND c.depth < 16
      )
      SELECT DISTINCT o.id AS id FROM open_items o
      WHERE o.id NOT IN (
        SELECT c.id FROM chain c
        JOIN items r ON r.id = c.cur
        WHERE r.parent = ''
      )
    ]])) do
    out[#out + 1] = ("%s: parent chain is broken or cyclic"):format(row.id)
  end
  return out
end

--- Every problem the index knows about: the row refusals `open`
--- collected, plus the dangling-parent, broken-chain, and
--- key-duplicate findings queried live from the loaded tables.
--- @param self Index The index
--- @return {string} Problem lines, possibly empty
local function problems(self: Index): {string}
  local out: {string} = {}
  for _, p in ipairs(self.load_problems) do
    out[#out + 1] = p
  end
  for _, p in ipairs(dangling_parents(self)) do
    out[#out + 1] = p
  end
  for _, p in ipairs(broken_chains(self)) do
    out[#out + 1] = p
  end
  for _, p in ipairs(key_duplicates(self)) do
    out[#out + 1] = p
  end
  return out
end

--- Close the connection. Idempotent, like `Database.close` itself.
--- @param self Index The index
--- @return boolean True on success
--- @return string Error message
local function close(self: Index): boolean, string
  return self.db:close()
end

--- Delete every row `id` owns, across `items` and everything that
--- references it (`ranks` where it is the parent — its own
--- ranked-children list — `builders`, `speccers`) — `_work.cache`'s
--- per-item invalidation, ahead of a fresh `insert_item` or on its own
--- when the item no longer exists. Order matters:
--- `builders.item`/`speccers.item` both carry a foreign key into
--- `items`, so the referencing rows go first. A rank entry some OTHER
--- item holds pointing at `id` is deliberately left standing —
--- dangling, exactly as `dangling_parents` already reports one after a
--- bulk `open` load.
--- @param db sqlite.Database The connection
--- @param id string Item id
--- @return boolean True on success
--- @return string Error message
local function delete_item(db: sqlite.Database, id: string): boolean, string
  for _, sql in ipairs({
      "DELETE FROM builders WHERE item = ?",
      "DELETE FROM speccers WHERE item = ?",
      "DELETE FROM ranks WHERE parent = ?",
      "DELETE FROM items WHERE id = ?",
    }) do
    local ok, err = db:exec(sql, {id})
    if not ok then
      return false, err
    end
  end
  return true, ""
end

--- Insert one item's rows — `items`, its own `ranks`
--- entries, `builders`, `speccers` — into a connection already
--- carrying this schema. Assumes none already exist for its id; call
--- `delete_item` first to refresh one already loaded. `_work.cache`'s
--- per-item counterpart to `open`'s bulk `load_items`, which this
--- reuses directly.
--- @param db sqlite.Database The connection
--- @param it Item The item
--- @return boolean True on success
--- @return string Error message
local function insert_item(db: sqlite.Database, it: Item): boolean, string
  local row_problems: {string} = {}
  load_items(db, {it}, row_problems)
  if #row_problems > 0 then
    return false, table.concat(row_problems, "; ")
  end
  return true, ""
end

local record index
  type Index = Index
  DDL: string
  open: function(items: {Item}, specs?: {string: string}): Index | nil, string
  problems: function(self: Index): {string}
  close: function(self: Index): boolean, string
  delete_item: function(db: sqlite.Database, id: string): boolean, string
  insert_item: function(db: sqlite.Database, it: Item): boolean, string
end

local M: index = {
  DDL = DDL,
  open = open,
  problems = problems,
  close = close,
  delete_item = delete_item,
  insert_item = insert_item,
}

return M
