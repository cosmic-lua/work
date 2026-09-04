--- The priority relation as SQL, proven equal to `_work.priority`'s
--- own Lua derivation by `_work.index_priority_test`'s differential
--- test. Layers three views onto an already-loaded `_work.index`
--- connection, on top of its `dominates` view: `own` (each item's
--- dominance count), `ancestors` (the parent chain, nearest first,
--- bounded the same 16 hops `_work.priority` uses), and `band` /
--- `unplaced` (the band a comparison at any height gives an item, or
--- NULL when none does) — `band` searches ancestors before the item's
--- own edge, mirroring `_work.priority.positions`'s search order
--- exactly.
---
--- Blocker-LIFT (`_work.priority`'s `lift`/`unblocks`, driven by
--- `blocked_by`) is deliberately NOT modeled here: with no
--- `blocked_by` edges on the board it is a no-op by construction
--- (nothing to lift, nothing to count), which is exactly the boards
--- the differential test builds. `order_ids` therefore reproduces
--- `_work.priority.sorted`'s UNSEEDED order (band, then own, then id)
--- exactly on those boards, not the lifted order a board carrying
--- blockers would need.
local index = require("_work.index")

local type Index = index.Index

--- The extra views, added to an index already carrying `_work.index`'s
--- own DDL (`items`, `edges`, `dominates`, ...).
local EXTRA_DDL < const > = [[
-- An item counts as "has an edge" only when the OTHER end is a real
-- item too — a dangling beats edge (`_work.index.dominates`'s own
-- join) never places its source, matching
-- `_work.priority.has_out_edge`'s `index[b] ~= nil` guard. The
-- `to_id` branch needs no extra join: `id` is already constrained to
-- an existing item by the outer `items` scan.
CREATE VIEW has_edge AS
  SELECT id FROM items WHERE id IN
    (SELECT e.from_id FROM edges e
     JOIN items i ON i.id = e.to_id WHERE e.kind = 'beats')
  UNION
  SELECT id FROM items WHERE id IN
    (SELECT to_id FROM edges WHERE kind = 'beats');

CREATE VIEW own AS
  SELECT i.id AS id, COUNT(d.loser) AS n
  FROM items i LEFT JOIN dominates d ON d.winner = i.id
  GROUP BY i.id;

-- The parent chain above each item, nearest ancestor first, NOT
-- including the item itself — `band`'s COALESCE below checks this
-- before the item's own edge, exactly the order
-- `_work.priority.positions` searches in.
CREATE VIEW ancestors AS
  WITH RECURSIVE anc(id, anc_id, depth) AS (
    SELECT id, parent, 1 FROM items WHERE parent <> ''
    UNION ALL
    SELECT a.id, i.parent, a.depth + 1
    FROM anc a JOIN items i ON i.id = a.anc_id
    WHERE i.parent <> '' AND a.depth < 16
  )
  SELECT id, anc_id, depth FROM anc;

CREATE VIEW band AS
  SELECT i.id AS id,
    COALESCE(
      (SELECT o.n FROM ancestors a
       JOIN has_edge h ON h.id = a.anc_id
       JOIN own o ON o.id = a.anc_id
       WHERE a.id = i.id
       ORDER BY a.depth ASC LIMIT 1),
      (SELECT o2.n FROM has_edge h2 JOIN own o2 ON o2.id = h2.id
       WHERE h2.id = i.id)
    ) AS n
  FROM items i;

CREATE VIEW unplaced AS
  SELECT id FROM band WHERE n IS NULL;
]]

--- Add the priority views to an index `_work.index.open` already
--- loaded. Call once per connection — a second call fails, the views
--- already existing.
--- @param idx Index An index from `_work.index.open`
--- @return boolean True on success
--- @return string Error message
local function ensure_views(idx: Index): boolean, string
  return idx.db:exec_script(EXTRA_DDL)
end

--- One item's placement: whether some comparison reaches it — an
--- ancestor's edge or its own — its band, and its own dominance count.
--- The SQL counterpart of `_work.priority.key_of` plus
--- `_work.priority.is_placed`; -1 for an unplaced id, matching
--- `key_of`'s own convention.
--- @param idx Index An index with `ensure_views` already applied
--- @param id string The item id
--- @return boolean True when placed
--- @return integer The band, -1 when unplaced
--- @return integer The item's own dominance count
local function position_of(idx: Index, id: string): boolean, integer, integer
  local row = assert(idx.db:query_one([[
      SELECT b.n AS band, o.n AS own FROM band b JOIN own o ON o.id = b.id
      WHERE b.id = ?
    ]], {id}))
  local own = math.tointeger(row.own) or 0
  if row.band == nil then
    return false, -1, own
  end
  return true, math.tointeger(row.band) or 0, own
end

--- Every item id in priority order: band descending, then own
--- descending, then id ascending — `_work.priority.sorted`'s unseeded
--- order on a board with no `blocked_by` edges (see the module header
--- for why that qualifier is exact, not approximate, there).
--- @param idx Index An index with `ensure_views` already applied
--- @return {string} Every item id, in order
local function order_ids(idx: Index): {string}
  local out: {string} = {}
  for row in assert(idx.db:query([[
      SELECT b.id AS id FROM band b JOIN own o ON o.id = b.id
      ORDER BY (b.n IS NOT NULL) DESC, b.n DESC, o.n DESC, b.id ASC
    ]])) do
    out[#out + 1] = row.id as string -- cast: from any (sqlite row)
  end
  return out
end

--- Ids a priority-edge cycle reaches (`dominates` self-pairs) — the
--- SQL counterpart of the id set `_work.priority.cycle_problems`
--- names.
--- @param idx Index An index from `_work.index.open`
--- @return {string: boolean} Ids in a cycle
local function cycle_ids(idx: Index): {string: boolean}
  local out: {string: boolean} = {}
  for row in assert(idx.db:query(
      "SELECT DISTINCT winner AS id FROM dominates WHERE winner = loser")) do
    local id = row.id as string -- cast: from any (sqlite row)
    out[id] = true
  end
  return out
end

--- Ids `unplaced` names — the SQL counterpart of
--- `not _work.priority.is_placed(...)`'s id set.
--- @param idx Index An index with `ensure_views` already applied
--- @return {string: boolean} Unplaced ids
local function unplaced_ids(idx: Index): {string: boolean}
  local out: {string: boolean} = {}
  for row in assert(idx.db:query("SELECT id FROM unplaced")) do
    local id = row.id as string -- cast: from any (sqlite row)
    out[id] = true
  end
  return out
end

local record index_priority
  ensure_views: function(idx: Index): boolean, string
  position_of: function(idx: Index, id: string): boolean, integer, integer
  order_ids: function(idx: Index): {string}
  cycle_ids: function(idx: Index): {string: boolean}
  unplaced_ids: function(idx: Index): {string: boolean}
end

local M: index_priority = {
  ensure_views = ensure_views,
  position_of = position_of,
  order_ids = order_ids,
  cycle_ids = cycle_ids,
  unplaced_ids = unplaced_ids,
}

return M
