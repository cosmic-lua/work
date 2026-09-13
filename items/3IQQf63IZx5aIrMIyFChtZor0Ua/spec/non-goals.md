- **No signature moves.** Q1–Q3 settled that none is available:
  `bind_at`, `is_blob`, `attach`, and the `Made` record all keep the
  declarations they have. Do not add a shared `cosmic/sqlite` types
  shard, and do not reverse either module's import direction.
- **No behaviour change beyond the two stated above** (`extras.tl`'s
  non-string pcall error value, and `fetch/extras.tl`'s truthy non-table
  `opts`). `cosmic.sqlite`'s transaction/savepoint verdict strings and
  `cosmic.fetch`'s response shape are frozen: `git diff origin/main --
  cosmic/sqlite/extras_test.tl` is empty and every `cosmic/fetch/*_test.tl`
  passes unmodified. No test file is edited by this slice at all.
- **Do not touch the guard half's nine files** (`cosmic/quicksand/box/**`,
  `cosmic/doc/query.tl`, `_docs/publish_test.tl`, `cosmic/searcher_test.tl`,
  `_perf/perf_test.tl`, `_perf/run.tl`, `cosmic/fs/path_test.tl`,
  `_perf/harness_test.tl`). The two slices are deliberately file-disjoint;
  only `_build/casts_baseline.tl` is shared, and a conflict there is the
  landing's mechanical regen, not a fresh review.
- **No new public module.** `_build/public_surface_baseline.tl` must not
  move.
- **Do not touch the other `from any` casts.** 46 lines carry that reason
  across 26 files at `c2ae0466` (`git ls-files '*.tl' | xargs grep -h --
  "-- cast: " | grep -c "from any"`, and the same pipeline with `grep -l
  ... | wc -l`; two of the 46 are string literals in `_build/casts_test.tl`
  that the lexer-based counter does not count). Only the eight above close
  here.
