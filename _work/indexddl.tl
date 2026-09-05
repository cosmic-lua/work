--- The core schema `_work.index` loads into every connection it opens:
--- item fields, the ranks relation, and the views every reader queries
--- instead of re-deriving role and state by hand. Split out of
--- `_work.index` to keep that module under its line cap — this file is
--- the DDL text alone, with no behavior of its own.
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
--- rather than trusted free text. `parent` and a rank's `child` are the
--- deliberate exceptions: neither carries a foreign key, so a dangling
--- one is a `problems()` QUERY finding rather than a load-time refusal
--- — the tree itself may carry a dangling reference (a hand edit, a
--- partial import, a stale rank entry left behind by a move —
--- `docs/design/order.md`'s "Moves and stale entries" — or a rank
--- entry naming something that never was a child at all), and this
--- index has to load it anyway to report on it.
---
--- `ranks` carries one row per entry of every item's own `order` list
--- (`parent` = that item's id) — the board's own outcome ranking
--- included, since it is an ordinary item's `order` field like any
--- other, not a separate table — `position` the entry's 1-based index
--- in the list AS STORED — a stale or otherwise non-child entry lands
--- verbatim; deriving a clean dense ranking from it is
--- `_work.index_rank`'s job, not the load's.
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
  resolution TEXT NOT NULL DEFAULT '' CHECK(resolution IN ('', 'completed', 'not-planned'))
) STRICT, WITHOUT ROWID;

-- One row per entry of every item's own `order` list (`parent` = that
-- item's id, the board's own outcome ranking included) — see the
-- module header. `child` deliberately carries no foreign key, the same
-- exception `edges.to_id` gets.
CREATE TABLE ranks (
  parent TEXT NOT NULL,
  position INTEGER NOT NULL,
  child TEXT NOT NULL,
  PRIMARY KEY(parent, position)
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

-- `parent` and a rank's `child` carry no foreign key (see the module
-- header), so nothing here forces their use — but both are join/filter
-- keys on every read: `containers` and `workable` filter items by
-- parent, `broken_chains`' walk searches for the board by `parent = ''`
-- at every recursive step, and `_work.index_rank`'s dense-position view
-- joins `ranks.child` against `items` once per rank entry.
-- `EXPLAIN QUERY PLAN` confirms SQLite picks these over a full scan
-- for both.
CREATE INDEX items_parent ON items(parent);
CREATE INDEX ranks_child ON ranks(child);

CREATE VIEW open_items AS
  SELECT * FROM items WHERE resolution = '';

-- The board: the one parentless item, in a well-formed tree.
CREATE VIEW roots AS
  SELECT * FROM items WHERE parent = '';

-- An item with an open child, whether or not the item itself is open
-- — matches `_work.flow.has_open_children`, which asks nothing about
-- the container's own state. Written as EXISTS rather than a
-- JOIN+DISTINCT: each `i` is wanted at most once regardless of how
-- many open children it has, and EXISTS gets there without a
-- deduplicating temp b-tree, searching `items_parent` for the child
-- check.
CREATE VIEW containers AS
  SELECT i.* FROM items i
  WHERE EXISTS (SELECT 1 FROM open_items c WHERE c.parent = i.id);

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
]]

local record indexddl
  DDL: string
end

local M: indexddl = {
  DDL = DDL,
}

return M
