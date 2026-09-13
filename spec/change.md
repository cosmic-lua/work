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
