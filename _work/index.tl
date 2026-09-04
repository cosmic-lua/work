--- A derived, in-memory SQLite index over the loaded item list. `open`
--- rebuilds it fresh from `store.list`/`store.read_specs` on every
--- verb invocation — it is never truth, never written back, and never
--- committed to git; the ref layout (`_work.store` and the modules
--- beside it) is the only durable state the board has. `_work.find`
--- layers full-text search on top of the same connection;
--- `_work.index_priority` adds the priority-relation views and proves
--- them equal to `_work.priority`'s own Lua derivation.
---
--- House defaults for any SQLite schema the board opens: every table
--- is `STRICT` (an FTS5 virtual table is the one exception — SQLite
--- cannot make one STRICT) with column types drawn only from the
--- STRICT set (`TEXT`, `INTEGER`, `REAL`, `BLOB`, `ANY` — no affinity
--- aliases like `VARCHAR`), a booleanish column is
--- `INTEGER ... CHECK(x IN (0, 1))`, a table whose primary key is TEXT
--- is `WITHOUT ROWID` so the key itself is the row's identity, foreign
--- keys are ON for the whole connection, and a closed vocabulary
--- (`verdict`, `resolution`, ...) is a `CHECK IN (...)` naming it
--- rather than trusted free text. `parent` and an edge's `to_id` are
--- the deliberate exceptions: neither carries a foreign key, so a
--- dangling one is a `problems()` QUERY finding rather than a load-time
--- refusal — the tree itself may carry a dangling reference (a hand
--- edit, a partial import), and this index has to load it anyway to
--- report on it.
local item = require("_work.item")
local sqlite = require("cosmic.sqlite")

local type Item = item.Item

--- The schema: item fields, the edge relation, and the views every
--- reader queries instead of re-deriving role and state by hand.
--- `dominates` is here (not in `_work.index_priority`) because
--- `problems` needs it for the priority-cycle finding; the rest of the
--- priority apparatus (`own`, `band`, `ancestors`, `unplaced`) is
--- layered on top by `_work.index_priority`, which this module does
--- not need.
local DDL < const > = [[
CREATE TABLE items (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL CHECK(length(title) > 0),
  parent TEXT NOT NULL DEFAULT '',
  repo TEXT NOT NULL DEFAULT '',
  base TEXT NOT NULL DEFAULT '',
  key TEXT NOT NULL DEFAULT '',
  claim TEXT NOT NULL DEFAULT '',
  reviewer TEXT NOT NULL DEFAULT '',
  pr INTEGER NOT NULL DEFAULT 0,
  result TEXT NOT NULL DEFAULT '',
  verdict TEXT NOT NULL DEFAULT '' CHECK(verdict IN ('', 'accept', 'request changes')),
  verdict_head TEXT NOT NULL DEFAULT '',
  verdict_spec TEXT NOT NULL DEFAULT '',
  resolution TEXT NOT NULL DEFAULT '' CHECK(resolution IN ('', 'completed', 'not-planned')),
  held INTEGER NOT NULL DEFAULT 0 CHECK(held IN (0, 1))
) STRICT, WITHOUT ROWID;

-- Every edge this build carries, of any kind: `beats` (the priority
-- relation), `blocked_by` (a reason per entry), and any OTHER kind an
-- item's tree names, which this index loads exactly like the two it
-- interprets. `to_id` deliberately carries no foreign key — see the
-- module header.
CREATE TABLE edges (
  kind TEXT NOT NULL,
  from_id TEXT NOT NULL REFERENCES items(id),
  to_id TEXT NOT NULL,
  reason TEXT NOT NULL DEFAULT '',
  PRIMARY KEY(kind, from_id, to_id)
) STRICT, WITHOUT ROWID;

CREATE TABLE builders (
  item TEXT REFERENCES items(id),
  session TEXT NOT NULL,
  seq INTEGER NOT NULL,
  PRIMARY KEY(item, seq)
) STRICT, WITHOUT ROWID;

CREATE TABLE speccers (
  item TEXT REFERENCES items(id),
  session TEXT NOT NULL,
  seq INTEGER NOT NULL,
  PRIMARY KEY(item, seq)
) STRICT, WITHOUT ROWID;

CREATE UNIQUE INDEX one_open_item_per_key
  ON items(key) WHERE key <> '' AND resolution = '';

CREATE VIEW open_items AS
  SELECT * FROM items WHERE resolution = '';

CREATE VIEW roots AS
  SELECT * FROM items WHERE parent = '';

-- An item with an open child, whether or not the item itself is open
-- — matches `_work.flow.has_open_children`, which asks nothing about
-- the container's own state.
CREATE VIEW containers AS
  SELECT DISTINCT i.* FROM items i
  JOIN open_items c ON c.parent = i.id;

CREATE VIEW workable AS
  SELECT i.* FROM open_items i
  WHERE i.parent <> ''
  AND NOT EXISTS (SELECT 1 FROM open_items c WHERE c.parent = i.id);

-- Mirrors `_work.flow.is_doing` and the resolution rule exactly; it
-- says nothing about role, the way `is_doing`/`is_open` do not either
-- — `workable` is where role is asked.
CREATE VIEW state AS
  SELECT id,
    CASE
      WHEN resolution <> '' THEN 'ended'
      WHEN claim <> '' OR pr <> 0 THEN 'doing'
      ELSE 'todo'
    END AS state
  FROM items;

-- Mirrors `_work.flow.substate` with no `queued` argument — the store
-- has no live GitHub read to supply one, which is exactly what
-- `substate`'s own header documents as its unsupplied-argument
-- behavior: an accept reads as the ordinary wait.
CREATE VIEW substate AS
  SELECT id,
    CASE
      WHEN verdict = 'accept' THEN 'accepted'
      WHEN verdict = 'request changes' THEN 'rework'
      WHEN pr <> 0 OR result <> '' THEN 'review'
      ELSE 'building'
    END AS substate
  FROM items;

-- The transitive closure of the `beats` kind: every (winner, loser)
-- pair one item outranks, directly or through the chain. A self-pair
-- (winner = loser) means the edges cycle through that item — the same
-- test `_work.priority.cycle_problems` runs in Lua. A dangling beats
-- edge (its `to_id` names no item) never enters the walk — matching
-- `_work.priority.walk`'s own `index[b] ~= nil` guard — so it counts
-- as a `dangling_edges` finding, never as standing: joined against
-- `items` at both the base case and every recursive step, since a
-- later hop can be the one that goes dangling.
CREATE VIEW dominates AS
  WITH RECURSIVE dom(winner, loser) AS (
    SELECT e.from_id, e.to_id FROM edges e
    JOIN items i ON i.id = e.to_id
    WHERE e.kind = 'beats'
    UNION
    SELECT d.winner, e.to_id FROM dom d
    JOIN edges e ON d.loser = e.from_id AND e.kind = 'beats'
    JOIN items i ON i.id = e.to_id
  )
  SELECT winner, loser FROM dom;
]]

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
        pr, result, verdict, verdict_head, verdict_spec, resolution, held)
      VALUES (:id, :title, :parent, :repo, :base, :key, :claim, :reviewer,
        :pr, :result, :verdict, :verdict_head, :verdict_spec, :resolution, :held)
    ]], {
        id = it.id, title = it.title, parent = it.parent or "",
        repo = it.repo or "", base = it.base or "", key = it.key or "",
        claim = it.claim or "", reviewer = it.reviewer or "",
        pr = it.pr or 0, result = it.result or "", verdict = it.verdict or "",
        verdict_head = it.verdict_head or "", verdict_spec = it.verdict_spec or "",
        resolution = it.resolution or "", held = it.is_held and 1 or 0,
      }, nil, problems, it.id)
    if landed then
      for _, b in ipairs(it.beats or {}) do
        try(db, [[
          INSERT OR IGNORE INTO edges(kind, from_id, to_id, reason)
          VALUES ('beats', ?, ?, '')
        ]], {it.id, b}, nil, problems, it.id)
      end
      for _, b in ipairs(it.blocked_by or {}) do
        try(db, [[
          INSERT OR IGNORE INTO edges(kind, from_id, to_id, reason)
          VALUES ('blocked_by', ?, ?, ?)
        ]], {it.id, b, (it.block_reason or {})[b] or ""}, nil, problems, it.id)
      end
      for kind, idmap in pairs(it.other_edges or {}) do
        for eid, reason in pairs(idmap) do
          try(db, [[
            INSERT OR IGNORE INTO edges(kind, from_id, to_id, reason)
            VALUES (?, ?, ?, ?)
          ]], {kind, it.id, eid, reason or ""}, nil, problems, it.id)
        end
      end
      for seq, name in ipairs(it.builders or {}) do
        try(db, "INSERT OR IGNORE INTO builders(item, session, seq) VALUES (?, ?, ?)",
          {it.id, name, seq}, nil, problems, it.id)
      end
      for seq, name in ipairs(it.speccers or {}) do
        try(db, "INSERT OR IGNORE INTO speccers(item, session, seq) VALUES (?, ?, ?)",
          {it.id, name, seq}, nil, problems, it.id)
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

--- Edges whose `to_id` names no row in `items` — a dangling `beats`,
--- `blocked_by`, or other-kind edge, queried live since the column
--- carries no foreign key.
--- @param self Index The index
--- @return {string} Problem lines, possibly empty
local function dangling_edges(self: Index): {string}
  local out: {string} = {}
  for row in assert(self.db:query([[
      SELECT kind, from_id, to_id FROM edges e
      WHERE NOT EXISTS (SELECT 1 FROM items i WHERE i.id = e.to_id)
    ]])) do
    out[#out + 1] = ("%s: %s %s, which is not an item"):format(
      row.from_id, row.kind, row.to_id)
  end
  return out
end

--- Open items whose ancestor walk, bounded the same 16 hops
--- `_work.priority`/`_work.flow` use, never reaches a root — a broken
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

--- Items a priority-edge cycle reaches — the SQL counterpart of
--- `_work.priority.cycle_problems`, read off `dominates` instead of
--- re-walking `beats` in Lua.
--- @param self Index The index
--- @return {string} Problem lines, possibly empty
local function priority_cycles(self: Index): {string}
  local out: {string} = {}
  for row in assert(self.db:query(
      "SELECT DISTINCT winner AS id FROM dominates WHERE winner = loser")) do
    out[#out + 1] = ("%s: priority edges form a cycle through it — the "
      .. "comparison was ambiguous; restate it and re-compare the pair")
    :format(row.id)
  end
  return out
end

--- Every problem the index knows about: the row refusals `open`
--- collected, plus the dangling-parent, dangling-edge, broken-chain,
--- priority-cycle and key-duplicate findings queried live from the
--- loaded tables.
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
  for _, p in ipairs(dangling_edges(self)) do
    out[#out + 1] = p
  end
  for _, p in ipairs(priority_cycles(self)) do
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

local record index
  type Index = Index
  DDL: string
  open: function(items: {Item}, specs?: {string: string}): Index | nil, string
  problems: function(self: Index): {string}
  close: function(self: Index): boolean, string
end

local M: index = {
  DDL = DDL,
  open = open,
  problems = problems,
  close = close,
}

return M
