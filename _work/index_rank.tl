--- The position-list rank order as SQL, over an index already carrying
--- `_work.index`'s `ranks` table (docs/design/order.md): each item's
--- position among its siblings at each level down from the board, the
--- one parentless item. `_work.rank` (Teal, over `item.Item.order`
--- directly) renders the same shape; the two are pinned against each
--- other.
---
--- `dense_rank` is one entry's position among a parent's list, counting
--- only entries that actually name a child of that parent (a stale
--- entry — the old parent's leftover after `attach` moved the item, or
--- a hand-edit naming something else entirely — is skipped and gets no
--- position, the same rule `_work.gitfsck.structural_problems` already
--- uses to flag one). One join condition covers every parent
--- uniformly, the board included: its own `order` field ranks its
--- outcomes exactly the way any other item's `order` ranks its
--- children — `ranks.parent` is that parent's real id either way, and
--- real children have `items.parent` equal to it.
---
--- `rank_path` is `_work.rank.key`/`is_ranked`'s SQL counterpart: a
--- recursive walk that starts at the board (`i.parent = ''`, key `''`,
--- contributing no path segment of its own — every item shares that
--- level) and continues DOWN to every descendant (bounded at 16 hops,
--- matching `_work.flow`'s own parent-chain trace bound), building each
--- item's `key` as it goes rather than assembling it after the fact,
--- since two items sharing an ancestor prefix must share that prefix's
--- TEXT exactly for `ORDER BY key` to group them correctly.
---
--- The key shape, per item: one 28-character field per level of the
--- path from the outcome down to the item itself inclusive, joined by
--- `/` — empty for the board itself, which has no outcome level. A
--- POSITIONED level's field is `0` followed by that level's dense rank
--- among ITS OWN parent's list (the outcome's "parent" being the
--- board's own `order`), zero-padded to 27 digits; an UNPOSITIONED
--- level's field is `1` followed by that level's own id (a
--- 27-character KSUID, so ids compare in age order) — every field
--- exactly 28 characters either way. `_work.rank` (Teal, over
--- `item.Item.order` directly) renders this exact shape; the two are
--- pinned against each other once both exist.
---
--- Fixed width is what makes plain lexicographic order do the whole
--- job: a shorter path is a true STRING PREFIX of every longer path
--- sharing its ancestors (no field ever swallows part of the next, the
--- way a variable-width field joined by a separator could), so
--- `ORDER BY key` puts an ancestor before its own descendants (the
--- board, with its empty key, before everything), a positioned level
--- (`0...`) before an unpositioned one (`1...`) at the SAME position in
--- the path, positioned levels in position order, and unpositioned
--- levels in age order by the appended id, all at once. `ORDER BY key,
--- id` breaks any remaining tie (two items with identical ancestor
--- prefixes reaching the 16-hop bound, say) by the item's own age.
---
--- `placed` is 1 iff the item's OUTCOME — its ancestor one level below
--- the board, itself when it is one — has a dense rank in the board's
--- own `order`; it is NOT lifted or recomputed per level below the
--- outcome, since docs/design/order.md's rule is exactly "an outcome
--- the board's list does not position, and everything under it, is
--- triage" — a deeper ancestor's own position (or lack of one) never
--- changes whether a descendant counts as placed. The board's own row
--- carries `placed = 1` trivially — it is never queued as workable, so
--- the value is never consulted.
local index = require("_work.index")

local type Index = index.Index

--- The extra views, added to an index already carrying `_work.index`'s
--- own DDL (`items`, `ranks`, ...).
local EXTRA_DDL < const > = [[
CREATE VIEW dense_rank AS
  SELECT r.parent AS parent, r.child AS child,
    ROW_NUMBER() OVER (PARTITION BY r.parent ORDER BY r.position) AS pos
  FROM ranks r
  JOIN items c ON c.id = r.child AND c.parent = r.parent;

-- A field is exactly 28 characters either way: `0` plus the dense
-- position zero-padded to 27 digits (`substr` of 27 zeros with the
-- position appended, taking the last 27 characters), or `1` plus the
-- 27-character id verbatim. The board's own row (depth 0) carries an
-- empty key and contributes no field of its own; the outcome level
-- (depth 0 -> 1) is the first to add one, and `placed` is fixed there
-- and simply carried forward unchanged at every deeper level.
CREATE VIEW rank_path AS
  WITH RECURSIVE rp(id, key, placed, depth) AS (
    SELECT i.id, '', 1, 0
    FROM items i
    WHERE i.parent = ''
    UNION ALL
    SELECT i.id,
      CASE WHEN rp.key = ''
        THEN
          CASE WHEN dr.pos IS NOT NULL
            THEN '0' || substr('000000000000000000000000000' || dr.pos, -27)
            ELSE '1' || i.id END
        ELSE rp.key || '/' ||
          CASE WHEN dr.pos IS NOT NULL
            THEN '0' || substr('000000000000000000000000000' || dr.pos, -27)
            ELSE '1' || i.id END
      END,
      CASE WHEN rp.depth = 0
        THEN CASE WHEN dr.pos IS NOT NULL THEN 1 ELSE 0 END
        ELSE rp.placed END,
      rp.depth + 1
    FROM rp
    JOIN items i ON i.parent = rp.id
    LEFT JOIN dense_rank dr ON dr.parent = rp.id AND dr.child = i.id
    WHERE rp.depth < 16
  )
  SELECT id, key, placed FROM rp;
]]

--- Add the rank views to an index `_work.index.open` already loaded.
--- Call once per connection — a second call fails, the views already
--- existing.
--- @param idx Index An index from `_work.index.open`
--- @return boolean True on success
--- @return string Error message
local function ensure_views(idx: Index): boolean, string
  return idx.db:exec_script(EXTRA_DDL)
end

--- One item's rank: whether its outcome is in the board's own `order`,
--- and its sortable path key. An id `rank_path` carries no row for (a
--- broken or cyclic parent chain past the 16-hop bound, or an id the
--- index never loaded) answers unplaced with an empty key —
--- `broken_chains` is where such a chain is actually reported.
--- @param idx Index An index with `ensure_views` already applied
--- @param id string The item id
--- @return boolean True when the item's outcome is in the board's own `order`
--- @return string The sortable path key, "" when `rank_path` has no row
local function rank_of(idx: Index, id: string): boolean, string
  local row = idx.db:query_one("SELECT key, placed FROM rank_path WHERE id = ?", {id})
  if row == nil then
    return false, ""
  end
  local placed = math.tointeger(row.placed as number) or 0 -- cast: from any (sqlite row)
  local key = row.key as string -- cast: from any (sqlite row)
  return placed == 1, key
end

--- Every item id `rank_path` carries a row for, in rank order: `key`
--- ascending, then `id` ascending as the final tie-break — ties in
--- `key` alone mean two items share identical ancestor prefixes all the
--- way to the 16-hop bound.
--- @param idx Index An index with `ensure_views` already applied
--- @return {string} Every ranked id, in order
local function order_ids(idx: Index): {string}
  local out: {string} = {}
  for row in assert(idx.db:query("SELECT id FROM rank_path ORDER BY key, id")) do
    out[#out + 1] = row.id as string -- cast: from any (sqlite row)
  end
  return out
end

local record index_rank
  ensure_views: function(idx: Index): boolean, string
  rank_of: function(idx: Index, id: string): boolean, string
  order_ids: function(idx: Index): {string}
end

local M: index_rank = {
  ensure_views = ensure_views,
  rank_of = rank_of,
  order_ids = order_ids,
}

return M
