- **Do not optimize either reader or writer.** `cosmic/literal.tl`,
  `cosmic/_literal_lex.tl` and `cosmic/_literal_format.tl` are not
  edited by this item. It builds the instrument; a hypothesis it
  later supports is a different item.
- **Do not gate anything on these numbers.** `--make ci` does not run
  `_perf` and must not start; the compare gate stays the manual loop
  the `optimize` skill describes.
- **Do not pass `literal.parse`'s `engine` option, if the tree has
  one.** (Board item `3IKSjS8N`, PR #1362, adds one.) The scenario
  measures what an ordinary caller gets from the default path.
  Measuring a specific implementation is a different scenario and a
  different item.
- **Do not read a committed file at bench time.** Every sibling
  scenario builds its input in memory, and a scenario that read
  `3p/cosmos/cosmos_pin.tl` or `.cosmic-coverage` would silently
  re-measure whenever those files changed.
- **Do not change the harness or the runner** — `_perf/harness.tl`,
  `_perf/run.tl`, `_perf/gate.tl`, `_perf/compare.tl`,
  `_perf/stats.tl`, `_perf/perf_types.tl` are all untouched, and so
  is `_perf/perf_test.tl` beyond the one-word comment fix.
- **Do not commit `o/perf/*.json`**, and do not add a baseline file.
