## Evidence

cosmic-lua/work#38 («KYPX_s06P») adds the cache's `events` table (one row
per commit on an item's ref, `verb`/`session`/`pr` parsed from the
subject) and the `pr_rounds` view (one row per item and PR round: first
take, verdict count, accept time). `_work/flowstats.tl` (375 lines) — the
G8 flow reader for lead time, rework rate and bounce counts — predates
both and derives the same facts a second way: it runs its own merged
`git log`, matches `id8`-embedded subjects with its own `try_take`/
`try_drop`/`try_verdict`/`try_done`/`try_review` parsers (lines 93-175),
accumulates per-item events (`events_of`, 175) and computes percentiles
(209). Two parsers of one commit-subject grammar drift independently; the
builder of #38 named the overlap in its report (2026-09-05).

## Change

1. `_work/flowstats.tl` reads `events` and `pr_rounds` through
   `cache.open` instead of walking `git log`; the `try_*` parsers go,
   `events_of` becomes a SELECT ordered by `seq`, and the per-item
   accumulation stays as the pure fold it is.
2. Lead time, rework rate and bounce counts are asserted equal, on a
   fixture board with one rework round and one bounce, between the
   pre-change reader (kept in the test as the oracle for this one PR)
   and the new one; then the oracle is deleted.
3. `percentile` stays until «ugSz_cxx8» (cosmic.bench) ships a public
   one.

## Non-goals

Changing what the stats mean or their printed shape; the events schema.
