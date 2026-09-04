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
--- rather than trusted free text.
local item = require("_work.item")
local sqlite = require("cosmic.sqlite")

local type Item = item.Item

--- The schema: item fields, the priority and blocker edges, and the
--- views every reader queries instead of re-deriving role and state by
--- hand. `dominates` is here (not in `_work.index_priority`) because
--- `problems` needs it for the priority-cycle finding; the rest of the
--- priority apparatus (`own`, `band`, `ancestors`, `unplaced`) is
--- layered on top by `_work.index_priority`, which this module does
--- not need.
local DDL < const > = [[
CREATE TABLE items (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL CHECK(length(title) > 0),
  parent TEXT REFERENCES items(id),
  repo TEXT NOT NULL DEFAULT '',
  base TEXT NOT NULL DEFAULT '',
  lane TEXT NOT NULL DEFAULT '',
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

CREATE TABLE beats (
  winner TEXT REFERENCES items(id),
  loser TEXT REFERENCES items(id),
  PRIMARY KEY(winner, loser)
) STRICT, WITHOUT ROWID;

CREATE TABLE blocked_by (
  item TEXT REFERENCES items(id),
  blocker TEXT REFERENCES items(id),
  reason TEXT NOT NULL DEFAULT '',
  PRIMARY KEY(item, blocker)
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

CREATE UNIQUE INDEX one_open_item_per_lane
  ON items(lane) WHERE lane <> '' AND resolution = '';

CREATE VIEW open_items AS
  SELECT * FROM items WHERE resolution = '';

CREATE VIEW roots AS
  SELECT * FROM items WHERE parent IS NULL;

-- An item with an open child, whether or not the item itself is open
-- — matches `_work.flow.has_open_children`, which asks nothing about
-- the container's own state.
CREATE VIEW containers AS
  SELECT DISTINCT i.* FROM items i
  JOIN open_items c ON c.parent = i.id;

CREATE VIEW workable AS
  SELECT i.* FROM open_items i
  WHERE i.parent IS NOT NULL
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

-- The transitive closure of `beats`: every (winner, loser) pair one
-- item outranks, directly or through the chain. A self-pair
-- (winner = loser) means the edges cycle through that item — the same
-- test `_work.priority.cycle_problems` runs in Lua.
CREATE VIEW dominates AS
  WITH RECURSIVE dom(winner, loser) AS (
    SELECT winner, loser FROM beats
    UNION
    SELECT d.winner, b.loser FROM dom d JOIN beats b ON d.loser = b.winner
  )
  SELECT winner, loser FROM dom;

-- Items whose row landed with `parent` left NULL because the parent it
-- actually named does not exist — as opposed to a genuine root, which
-- never named one. `broken_chains` treats only the latter as a chain's
-- valid end; walking through one of these is still broken, the same
-- way `_work.flow.root_of` never treats a nonexistent parent as a root.
CREATE TABLE refused_parent (
  id TEXT PRIMARY KEY
) STRICT, WITHOUT ROWID;
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

--- Every item's row, in two passes so a valid parent never depends on
--- INSERT order: pass one writes every item with `parent` left NULL —
--- which foreign keys never check — and pass two sets it, by which
--- point every item that loaded at all already has a row. Only a
--- GENUINELY dangling or malformed parent fails pass two, and its
--- message is written to match `_work.flow.item_problems`'s own
--- wording exactly, so the two are trivially comparable in the ratchet
--- test. Immediate (non-deferred) foreign-key checking is deliberate:
--- `PRAGMA defer_foreign_keys` pushes a violation to COMMIT, where it
--- would roll back the WHOLE transaction — exactly the abort-on-one-
--- bad-row outcome this load must not have.
--- @param db sqlite.Database The connection
--- @param items {Item} Every item to load
--- @param problems {string} Problem lines, appended to on any refusal
local function load_items(db: sqlite.Database, items: {Item}, problems: {string})
  local by_id: {string: Item} = {}
  for _, it in ipairs(items) do
    by_id[it.id] = it
  end
  local landed: {string: boolean} = {}
  for _, it in ipairs(items) do
    landed[it.id] = try(db, [[
      INSERT INTO items(id, title, repo, base, lane, claim, reviewer, pr,
        result, verdict, verdict_head, verdict_spec, resolution, held)
      VALUES (:id, :title, :repo, :base, :lane, :claim, :reviewer, :pr,
        :result, :verdict, :verdict_head, :verdict_spec, :resolution, :held)
    ]], {
        id = it.id, title = it.title, repo = it.repo or "", base = it.base or "",
        lane = it.lane or "", claim = it.claim or "", reviewer = it.reviewer or "",
        pr = it.pr or 0, result = it.result or "", verdict = it.verdict or "",
        verdict_head = it.verdict_head or "", verdict_spec = it.verdict_spec or "",
        resolution = it.resolution or "", held = it.is_held and 1 or 0,
      }, nil, problems, it.id)
  end
  for _, it in ipairs(items) do
    if landed[it.id] and (it.parent or "") ~= "" then
      -- A refused parent leaves the row rootless rather than
      -- dangling on an id no other row carries: every view still
      -- reads it, just as an (incorrectly) parentless item rather
      -- than one pointing nowhere. `refused_parent` remembers WHICH
      -- rootless rows are this — refused, not genuinely rootless — so
      -- `broken_chains` can tell the two apart.
      local ok = try(db, "UPDATE items SET parent = :parent WHERE id = :id",
        {parent = it.parent, id = it.id},
        ("%s: parent %s does not exist"):format(it.id, it.parent),
        problems, it.id)
      if not ok then
        assert(db:exec("INSERT INTO refused_parent(id) VALUES (?)", {it.id}))
      end
    end
  end
  for _, it in ipairs(items) do
    if landed[it.id] then
      for _, b in ipairs(it.beats or {}) do
        if by_id[b] == nil then
          problems[#problems + 1] = ("%s: beats names %s, not on the board "
            .. "(dangling edge)"):format(it.id, b)
        elseif landed[b] then
          try(db, "INSERT OR IGNORE INTO beats(winner, loser) VALUES (?, ?)",
            {it.id, b}, nil, problems, it.id)
        end
      end
      for _, b in ipairs(it.blocked_by or {}) do
        if by_id[b] == nil then
          problems[#problems + 1] = ("%s: blocked_by names %s, not on the "
            .. "board (dangling edge)"):format(it.id, b)
        elseif landed[b] then
          try(db, [[
            INSERT OR IGNORE INTO blocked_by(item, blocker, reason)
            VALUES (?, ?, ?)
          ]], {it.id, b, (it.block_reason or {})[b] or ""}, nil, problems, it.id)
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

--- Items sharing one non-empty lane while both are open — always empty
--- given `one_open_item_per_lane`'s unique index already refuses the
--- second such row at load; kept as a live, queried check on the
--- invariant rather than trusted to the index definition alone.
--- @param self Index The index
--- @return {string} Problem lines, possibly empty
local function lane_duplicates(self: Index): {string}
  local out: {string} = {}
  for row in assert(self.db:query([[
      SELECT lane, COUNT(*) AS n FROM open_items
      WHERE lane <> '' GROUP BY lane HAVING COUNT(*) > 1
    ]])) do
    out[#out + 1] = ("lane %s is claimed by %d open items at once"):format(
      row.lane, math.tointeger(row.n) or 0)
  end
  return out
end

--- Open items whose ancestor walk, bounded the same 16 hops
--- `_work.priority`/`_work.flow` use, never reaches a root — a broken
--- or cyclic parent chain past the immediate parent, which the load's
--- own per-row check (a missing DIRECT parent) cannot see.
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
        WHERE i.parent IS NOT NULL AND c.depth < 16
      )
      SELECT DISTINCT o.id AS id FROM open_items o
      WHERE o.id NOT IN (
        SELECT c.id FROM chain c
        JOIN items r ON r.id = c.cur
        WHERE r.parent IS NULL
        AND r.id NOT IN (SELECT id FROM refused_parent)
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
--- collected, plus the dangling-edge, lane-duplicate, broken-chain and
--- priority-cycle findings queried live from the loaded tables.
--- @param self Index The index
--- @return {string} Problem lines, possibly empty
local function problems(self: Index): {string}
  local out: {string} = {}
  for _, p in ipairs(self.load_problems) do
    out[#out + 1] = p
  end
  for _, p in ipairs(broken_chains(self)) do
    out[#out + 1] = p
  end
  for _, p in ipairs(priority_cycles(self)) do
    out[#out + 1] = p
  end
  for _, p in ipairs(lane_duplicates(self)) do
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
