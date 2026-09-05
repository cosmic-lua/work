--- The `events` table's schema, plus `pr_rounds`, the one view that
--- answers the three questions `_work.events`'s own header raises
--- ("which PR heads did this item see, and when", "how long from take
--- to accept", "every item whose PR was reworked before acceptance")
--- with one SELECT each — held by `_work.events_test.tl`, the way
--- `_work.index`'s state views are held by `_work.index_test`.
---
--- One row per commit on an item's ref (`item` REFERENCES `items(id)`,
--- `seq` its position from the root — 1 is the item's own `new`):
--- `verb`, `session`, and `pr` are `_work.events.parse_subject`'s
--- three fields, so a legacy commit this fixed grammar cannot parse
--- still gets a row, just an unclassified one (`verb` the whole
--- leading token, `session`/`pr` left at their defaults); `subject`
--- is kept verbatim so nothing about a legacy shape is lost. `pr` and
--- `verb` each carry an index — `events_pr` partial (most rows carry
--- no `pr:N` token at all, per `_work.events`'s own header) — since
--- both are how a reader is expected to filter: every commit a given
--- PR round touched, or every `verdict` (or `take`, or `done`) across
--- the whole board.
---
--- Split out of `_work.cachedb` so that module's own DDL constant —
--- concatenated with this one at load time, so a caller of
--- `cachedb.EXTRA_DDL` sees a single string exactly as if this were
--- inline — stays under the repo's line cap. `_work.cachedb` is the
--- only place this is required from; its schema fingerprint (built
--- from `sqlite_master`, never source text) covers whatever this file
--- defines exactly as it would an inline table.
local EXTRA_DDL < const > = [[
CREATE TABLE events (
  item TEXT NOT NULL REFERENCES items(id),
  seq INTEGER NOT NULL,
  sha TEXT NOT NULL,
  at INTEGER NOT NULL,
  verb TEXT NOT NULL,
  session TEXT NOT NULL DEFAULT '',
  pr INTEGER NOT NULL DEFAULT 0,
  subject TEXT NOT NULL,
  PRIMARY KEY(item, seq)
) STRICT, WITHOUT ROWID;

CREATE INDEX events_pr ON events(pr) WHERE pr <> 0;
CREATE INDEX events_verb ON events(verb);

-- One row per (item, pr) — NOT per `take` event: the normal flow after
-- a `request changes` is fix, then re-take the SAME pr to ask for
-- review again, which writes a SECOND `take ... pr:N` commit with the
-- identical N. Grouping on `take` rows alone (a first attempt at this
-- view did) reads that as a second round every time, so "reworked
-- before acceptance" was a false positive on 38 of the live board's 39
-- flagged items. `takes` below merges every RUN of consecutive
-- same-pr `take` rows into one group with the classic gaps-and-islands
-- trick — `ROW_NUMBER() OVER (whole item)` minus `ROW_NUMBER() OVER
-- (this pr only)` is constant across a run and changes the moment the
-- pr does, whether it changes to a new number or BACK to an old one
-- (a real second round under a reused pr, not the same run) — so
-- `rounds` collapses each run to its first `take`'s time, and `bounded`
-- reads a round's span off the NEXT round's start, open-ended for an
-- item's last one. `verdicts`/`accepted_at` then count within that
-- whole span, so a same-pr re-take never starts a fresh count. A round
-- with no accept yet — still under review, or superseded by a later
-- pr before one landed — carries `accepted_at` NULL, which is how
-- "every item whose PR was reworked before acceptance" reads: more
-- than one row per item, at most one of them with a non-null
-- `accepted_at`. `verdict`'s own subject never carries `pr:N` — only
-- `take` does — so nothing here reads `pr` off a verdict row.
CREATE VIEW pr_rounds AS
WITH takes AS (
  SELECT item, pr, seq, at,
    ROW_NUMBER() OVER (PARTITION BY item ORDER BY seq)
      - ROW_NUMBER() OVER (PARTITION BY item, pr ORDER BY seq) AS grp
  FROM events
  WHERE verb = 'take' AND pr <> 0
),
rounds AS (
  SELECT item, pr, grp, MIN(seq) AS start_seq, MIN(at) AS taken_at
  FROM takes
  GROUP BY item, pr, grp
),
bounded AS (
  SELECT r.item, r.pr, r.taken_at, r.start_seq,
    COALESCE(
      (SELECT MIN(r2.start_seq) FROM rounds r2
        WHERE r2.item = r.item AND r2.start_seq > r.start_seq),
      9223372036854775807) AS end_seq
  FROM rounds r
)
SELECT
  b.item AS item,
  b.pr AS pr,
  b.taken_at AS taken_at,
  (SELECT COUNT(*) FROM events v WHERE v.item = b.item AND v.verb = 'verdict'
    AND v.seq > b.start_seq AND v.seq < b.end_seq) AS verdicts,
  (SELECT MAX(v.at) FROM events v WHERE v.item = b.item AND v.verb = 'verdict'
    AND v.seq > b.start_seq AND v.seq < b.end_seq
    AND v.subject LIKE 'verdict % accept%') AS accepted_at
FROM bounded b;
]]

local record cachedb_events
  EXTRA_DDL: string
end

local M: cachedb_events = {
  EXTRA_DDL = EXTRA_DDL,
}

return M
