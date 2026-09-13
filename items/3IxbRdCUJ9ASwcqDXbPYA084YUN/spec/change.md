Make each under-floor file refusal name its uncovered analyzed-code lines.

1. Extract `report.format_ranges(sorted_lines, max_ranges)` into new
   `_tool/coverage/gaps.tl`, preserving its range compaction and truncation
   behavior.  Keep `report.format_ranges` as an alias so existing callers and
   tests remain compatible.
2. In `_tool/coverage/minimum.violations`, append
   `  uncovered: <ranges>` to each declined file row whose `missing` list is
   nonempty, using a fixed eight-range display limit.  Preserve percentages,
   thresholds, ordering, totals, and the trailing `declined:` summary.
3. Add `_tool/coverage/gaps_test.tl` cases for one line, one run, mixed runs,
   no gaps, and truncation.  Add a `minimum_test.tl` fixture whose merged
   coverage yields `2/6` and missing lines `3,5-6,8`; assert that exact suffix,
   that a fully covered companion emits no refusal, and that the final summary
   is unchanged.
4. Add one sentence beside the coverage-floor output in
   `docs/guides/make.md`: declined file rows include compact uncovered-line
   ranges from the same merged coverage data.  If navigation is discussed,
   call these analyzed-code line numbers because generated Lua and displayed
   Teal line numbers can differ.

Allow only `_tool/coverage/report.tl`, `_tool/coverage/gaps.tl`,
`_tool/coverage/gaps_test.tl`, `_tool/coverage/minimum.tl`,
`_tool/coverage/minimum_test.tl`, and `docs/guides/make.md`.  Cap the total
diff at 200 changed lines.  Bounce rather than touching `_make/policy*`,
changing `FileReport`, or adding new coverage-state plumbing.

Run focused gaps/report/minimum tests, format/types for changed Teal, and
`bin/cosmic --make ci`.  Mutation: remove only the refusal suffix append; the
minimum-gate regression must fail while threshold behavior remains unchanged,
then restore it.
