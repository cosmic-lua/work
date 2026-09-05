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

-- One row per (item, pr): the round's first `take ... pr:N` time, how
-- many `verdict` rows the round drew, and when (if ever) one of them
-- was an accept. A round with no accept yet — still under review, or
-- sent back for rework under a later `pr:M` — carries `accepted_at`
-- NULL, which is how "every item whose PR was reworked before
-- acceptance" reads: more than one row per item, at most one of them
-- with a non-null `accepted_at`. `verdict`'s own subject never repeats
-- `pr:N` (only `take` does — `_work.gitverdict`'s subject carries no
-- such token), so a round's bounds are read off `seq`: from its own
-- `take` up to (not including) the item's next `take`, open-ended
-- for the item's last round.
CREATE VIEW pr_rounds AS
SELECT
  t.item AS item,
  t.pr AS pr,
  t.at AS taken_at,
  (SELECT COUNT(*) FROM events v WHERE v.item = t.item AND v.verb = 'verdict'
    AND v.seq > t.seq AND v.seq < t.next_seq) AS verdicts,
  (SELECT MAX(v.at) FROM events v WHERE v.item = t.item AND v.verb = 'verdict'
    AND v.seq > t.seq AND v.seq < t.next_seq
    AND v.subject LIKE 'verdict % accept%') AS accepted_at
FROM (
  SELECT item, pr, seq, at,
    COALESCE(
      (SELECT MIN(seq) FROM events later
        WHERE later.item = e.item AND later.verb = 'take' AND later.seq > e.seq),
      9223372036854775807) AS next_seq
  FROM events e
  WHERE e.verb = 'take' AND e.pr <> 0
) AS t;
]]

local record cachedb_events
  EXTRA_DDL: string
end

local M: cachedb_events = {
  EXTRA_DDL = EXTRA_DDL,
}

return M
