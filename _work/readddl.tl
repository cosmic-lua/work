--- An item's rank is a path: its position among its siblings at each
--- level down from the board, the one parentless item. Rank among
--- siblings is a position in a list the parent holds; siblings not in
--- the list follow it, by age. An outcome the board's list does not
--- position, and everything under it, is triage.
---
--- `gitboard help order` is pinned to the paragraph above, verbatim
--- (`_work.doctrine_test`) — it must read exactly the same, so the two
--- can never drift apart in meaning.
---
--- The derived-view DDL this file adds on top of `_work.indexddl`'s
--- base schema and `_work.index_rank`'s rank views: role, stage, the
--- single unified queue, the board's outcomes with their live flag,
--- triage, the doing count, a per-item children listing, the claims
--- and review claims standing past their lease, and the whole-board
--- structural-problem findings. Every view here is read-only SQL — the
--- one implementation of a fact every verb reads through
--- `_work.read`'s typed functions over it, never re-derived in Teal.
---
--- Apply after `_work.index.open`'s own DDL AND
--- `_work.index_rank.ensure_views` — `queue`, `outcomes`, and
--- `triage` below all join against `rank_path`/`dense_rank`, so those
--- must exist first. `_work.cacherebuild.rebuild` applies both, once,
--- to every persisted cache file; `_work.read` is the typed reader
--- every verb queries through, via `_work.store.read`'s open handle.
local index = require("_work.index")

local type Index = index.Index

--- The extra views, added to an index already carrying
--- `_work.index`'s base DDL and `_work.index_rank`'s `dense_rank`/
--- `rank_path`.
local EXTRA_DDL < const > = [[
-- board: the one parentless item (docs/design/order.md). More than one
-- can exist on a broken tree (`structure` reports the rest), so the
-- choice is made deterministic the same way `_work.flow.find_board`
-- makes it — walking items in id order and taking the first — since
-- `store.list`'s own order is id-ascending.
CREATE VIEW board AS
  SELECT * FROM items WHERE parent = '' ORDER BY id LIMIT 1;

-- role: id -> 'board' | 'outcome' | 'container' | 'work', for EVERY
-- item, done ones included (`show` prints a done item's role too) —
-- matches `_work.flow.role` exactly: the board first (parentless),
-- then any item with an open child (`containers`, decomposition beats
-- everything below it), then a direct child of a parentless item
-- (`_work.flow.is_outcome` asks the same question — any parentless
-- item counts, not only the canonical `board` row above), else work.
CREATE VIEW role AS
  SELECT i.id AS id,
    CASE
      WHEN i.parent = '' THEN 'board'
      WHEN i.id IN (SELECT id FROM containers) THEN 'container'
      WHEN EXISTS (SELECT 1 FROM items p WHERE p.id = i.parent AND p.parent = '')
        THEN 'outcome'
      ELSE 'work'
    END AS role
  FROM items i;

-- stage: id -> the integer `_work.flow.stage_rank` gives, for open
-- work items only (`workable`): accepted 1, review 2, rework 3,
-- building 4 for a doing item (`state`/`substate` already derive
-- which); repair 5 for a todo item carrying a lane-repair `key`;
-- ordinary todo 6.
CREATE VIEW stage AS
  SELECT w.id AS id,
    CASE
      WHEN st.state = 'doing' THEN
        CASE sub.substate
          WHEN 'accepted' THEN 1
          WHEN 'review' THEN 2
          WHEN 'rework' THEN 3
          ELSE 4
        END
      WHEN w.key <> '' THEN 5
      ELSE 6
    END AS stage
  FROM workable w
  JOIN state st ON st.id = w.id
  JOIN substate sub ON sub.id = w.id;

-- queue: every open work item with its stage and rank-path key, in
-- the order every verb walks: stage, then key, then id. The seeded
-- per-session tie-break stays policy, applied by `next` over rows
-- this view leaves tied on `id`. An item whose own parent chain is absent from
-- `rank_path` (broken or deeper than 16 levels) still queues, with the
-- same one-field fallback key `_work.rank.key` gives it: "1" plus its
-- own id, which is already `_work.rank.FIELD_WIDTH` characters for a
-- real KSUID.
CREATE VIEW queue AS
  SELECT w.id AS id, s.stage AS stage,
    COALESCE(rp.key, '1' || w.id) AS key
  FROM workable w
  JOIN stage s ON s.id = w.id
  LEFT JOIN rank_path rp ON rp.id = w.id;

-- outcome_descendants: every (root, id) pair where `root` is an
-- outcome (a direct child of a parentless item) and `id` is `root`
-- itself or one of its descendants, bounded 15 hops down from the
-- outcome — matching `_work.flow.outcome_of`'s own climb, which tests
-- at most 16 candidate ancestors (hops 0..15) before giving up. A
-- helper for `outcomes.live` alone; nothing outside this file reads it.
CREATE VIEW outcome_descendants AS
  WITH RECURSIVE d(root, id, depth) AS (
    SELECT o.id, o.id, 0
    FROM items o
    JOIN items b ON b.id = o.parent AND b.parent = ''
    UNION ALL
    SELECT d.root, c.id, d.depth + 1
    FROM d
    JOIN items c ON c.parent = d.id
    WHERE d.depth < 15
  )
  SELECT root, id FROM d;

-- outcomes: the board's positioned open children, with `live` = 1 iff
-- an open, non-outcome item's parent chain reaches it before reaching
-- the board; an outcome never counts as its own live descendant.
CREATE VIEW outcomes AS
  SELECT o.id AS id, rp.key AS key,
    CASE WHEN EXISTS (
      SELECT 1 FROM outcome_descendants d
      JOIN open_items od ON od.id = d.id
      WHERE d.root = o.id AND d.id <> d.root
    ) THEN 1 ELSE 0 END AS live
  FROM open_items o
  JOIN items b ON b.id = o.parent AND b.parent = ''
  JOIN rank_path rp ON rp.id = o.id
  WHERE rp.placed = 1;

-- triage: the board's open, unpositioned, childless children
-- (`_work.flow.untriaged`) — a captured outcome nothing has ranked,
-- decomposed, or ended yet.
CREATE VIEW triage AS
  SELECT o.id AS id
  FROM open_items o
  JOIN items b ON b.id = o.parent AND b.parent = ''
  LEFT JOIN rank_path rp ON rp.id = o.id
  WHERE NOT EXISTS (SELECT 1 FROM open_items c WHERE c.parent = o.id)
  AND (rp.placed IS NULL OR rp.placed = 0);

-- doing: one row, the count of open work items with a claim or a PR —
-- `_work.flow.doing_refusal`'s own count, read against `DOING_LIMIT`
-- there; this view carries the count alone, not the bound or the
-- refusal message.
CREATE VIEW doing AS
  SELECT COUNT(*) AS n
  FROM workable w
  JOIN state st ON st.id = w.id
  WHERE st.state = 'doing';

-- stale: claims and review claims past their lease, from
-- `items.touched_at` — `_work.health.LEASE_S` (claim, 14400s/4h) and
-- `_work.health.REVIEW_LEASE_S` (review, 3600s/1h) restated here as
-- literal seconds, since a view cannot read a Teal constant; keep the
-- two in sync by hand. One row per lease currently past its horizon:
-- (id, kind, age_s).
CREATE VIEW stale AS
  SELECT id, 'claim' AS kind,
    (CAST(strftime('%s', 'now') AS INTEGER) - touched_at) AS age_s
  FROM open_items
  WHERE claim <> ''
  AND (CAST(strftime('%s', 'now') AS INTEGER) - touched_at) > 14400
  UNION ALL
  SELECT id, 'review' AS kind,
    (CAST(strftime('%s', 'now') AS INTEGER) - touched_at) AS age_s
  FROM open_items
  WHERE reviewer <> ''
  AND (CAST(strftime('%s', 'now') AS INTEGER) - touched_at) > 3600;

-- children: (parent, child, position, open) for every item that has
-- one — `position` is the child's dense rank in the parent's own
-- `order` when it has one, NULL when it is unranked among its
-- siblings; `open` is the CHILD's own state. What a `show ID` children
-- listing reads.
CREATE VIEW children AS
  SELECT i.parent AS parent, i.id AS child, dr.pos AS position,
    CASE WHEN i.resolution = '' THEN 1 ELSE 0 END AS open
  FROM items i
  LEFT JOIN dense_rank dr ON dr.parent = i.parent AND dr.child = i.id
  WHERE i.parent <> '';

-- structure: the whole-board audit findings a SQL view can answer
-- without a git object read — the same five kinds
-- `_work.gitfsck.structural_problems` and `_work.index`'s own live
-- queries (`dangling_parents`, `key_duplicates`) already check, plus
-- `rank_path`'s own bound standing in for `broken_chains`: a dangling
-- parent, a second parentless item, an `order` entry naming a
-- non-child, two open items sharing a key, and a parent chain deeper
-- than 16 (absent from `rank_path` entirely). One row per finding:
-- (kind, id, detail).
CREATE VIEW structure AS
  SELECT 'dangling_parent' AS kind, i.id AS id,
    'parent ' || i.parent || ' does not exist' AS detail
  FROM items i
  WHERE i.parent <> '' AND NOT EXISTS (SELECT 1 FROM items p WHERE p.id = i.parent)
  UNION ALL
  SELECT 'second_root' AS kind, i.id AS id,
    'a second parentless item; the board is ' ||
      COALESCE((SELECT id FROM board), '') AS detail
  FROM items i
  WHERE i.parent = '' AND i.id <> COALESCE((SELECT id FROM board), '')
  UNION ALL
  SELECT 'stale_order' AS kind, r.parent AS id,
    'order names ' || r.child || ', which is not a child of it' AS detail
  FROM ranks r
  LEFT JOIN items c ON c.id = r.child AND c.parent = r.parent
  WHERE c.id IS NULL
  -- `one_open_item_per_key` already refuses a second OPEN item sharing
  -- a key at load time (see `_work.index.key_duplicates`'s own header),
  -- so — like that Teal check — this kind can never actually fire
  -- through the ordinary `_work.index.open` path: the offending row
  -- never lands in `items` to be found here. Kept anyway as the same
  -- live, queried check on the invariant `key_duplicates` already
  -- states the reason for, in case the day this index stops enforcing
  -- it at load ever comes.
  UNION ALL
  SELECT 'duplicate_key' AS kind, o.id AS id,
    'shares key ' || o.key || ' with ' || (d.n - 1) || ' other open item(s)' AS detail
  FROM open_items o
  JOIN (
    SELECT key, COUNT(*) AS n FROM open_items WHERE key <> '' GROUP BY key HAVING COUNT(*) > 1
  ) d ON d.key = o.key
  UNION ALL
  SELECT 'deep_chain' AS kind, o.id AS id,
    'parent chain is broken, cyclic, or deeper than 16 levels' AS detail
  FROM open_items o
  LEFT JOIN rank_path rp ON rp.id = o.id
  WHERE rp.id IS NULL;
]]

--- Add slice R2's read views to an index that already carries
--- `_work.index`'s base DDL and `_work.index_rank.ensure_views`. Call
--- once per connection — a second call fails, the views already
--- existing.
--- @param idx Index An index with `_work.index_rank.ensure_views` already applied
--- @return boolean True on success
--- @return string Error message
local function ensure_views(idx: Index): boolean, string
  return idx.db:exec_script(EXTRA_DDL)
end

local record readddl
  ensure_views: function(idx: Index): boolean, string
end

local M: readddl = {
  ensure_views = ensure_views,
}

return M
