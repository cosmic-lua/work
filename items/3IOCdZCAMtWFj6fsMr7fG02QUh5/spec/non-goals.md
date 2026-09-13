- **`--filter` is NOT in this slice.** It was in the item's title; it is
  cut, and the reason is measured: the flag has nowhere to be spelled.
  `wc -l cmd/cosmic/main.tl` is **499** and `wc -l _make/init.tl` is
  **498**, against a hard cap of 500 (`_tool/lint.tl:31`, refusing
  `n > limit`) — one and two lines of headroom, so neither
  `cosmic --test … --filter` nor `--make test … --filter` can be added
  without splitting a file first. And the capability substantially exists:
  `_tool/testrun.tl:59-69` copies the whole parent environment to the
  child, excluding only `COSMIC_COVERAGE` and `COSMIC_MAKE_ROOT`, so an
  ambient `COSMIC_TEST_FILTER` already reaches `cosmic/test.tl:47-62`,
  which already honours it. What is genuinely missing is the flag spelling
  and graph invalidation (nothing declares `COSMIC_TEST_FILTER`, so
  `_make/envstamp.tl` does not make its value a prerequisite and a
  narrowed re-run replays cached `.got` files). Filed separately as
  **3IUCW3Wj**. Do not add a `filter` parameter to `testrun.run` here: with
  no caller it is dead surface, and `parse_cases` already falls back
  correctly under an ambient filter.
- **`records.counts` and the summary's `N checks:` line stay FILE-based.**
  `_make/stage.tl:221` derives every stage verdict from that line via
  `records.stage_detail(summary, #files, "file")`, and all six stages share
  one `--report` (`embed/cosmic.mk:158,199,222,243,266,294`). Re-pointing
  it at tests would print `test: FAIL (4 of 2786 files)`. The tests line is
  ADDITIONAL and must sit after the checks line, because
  `parse_counts`' `", (%d+) failed"` and `", (%d+) skipped"` patterns are
  unanchored and take the first match in the text.
- **The row format does not move.** `records.row(status, name, count,
  "test functions", wall_ms)` and its `✓ path (14 test functions) 12ms`
  rendering stay byte-identical; `test_count` stays a count of `.tests`
  lines.
- **`.tests` stays one line per test.** That invariant is what the
  existing in-tree consumer at `_tool/testrun.tl:247` counts, and it is the
  only consumer — `grep -rn '\.tests' --include=*.tl --include=*.mk . |
  grep -v '^./o/'` returns 5 hits, all in `_tool/testrun.tl`, two of them
  comments and one a diagnostic string.
- **`cosmic/test.tl` is not touched.** It is PUBLIC API frozen by D29, and
  quiet-on-pass is a stated property: do NOT add a per-test pass line to
  make parsing easier. `_tool/records_test.tl`'s existing agreement between
  the two spellings stays as it is.
- **`_tool/discover.tl` is not required from `testrun.tl`.** Its token walk
  and the existing `^local function (test_[%w_]+)` regex can disagree on a
  definition whose `end` the walk loses (`_tool/discover.tl:113-118`), and
  swapping them would silently change the `(N test functions)` annotation
  on some file. Keep the regex.
- No new flags, no new sidecar files, no per-test wall time, no per-test
  skip, no change to the 0/2/fail exit grammar, no change to the migration
  items under `3IOCdooE`, and no edits to `docs/agent-usability.md`
  (item 6 there stays true — per-file counts and the row are unchanged).
