- **Do not give the BASELINE pair its own noise credit** and do not add a
  second control GROUP to `triage_many`. That is item `3IWx3I4Z` and
  D34's third rejected option. This change reads only current-side
  pairs. It does export `loudest_control`, which `3IWx3I4Z` also expects
  to need — that half is settled here, and `3IWx3I4Z` inherits it.
- **Do not change `TRIAGE_K`, `DEFAULT_THRESHOLD_PCT`, or `diff`'s
  verdict vocabulary.** D31 governs how much variance a scenario is
  credited for and stands unamended; this change adds a new PLACE the
  existing credit is read, not a new credit.
- **Do not change the union rule.** A regression flagging only in the
  retry still reclassifies to `noise` with no control requirement
  (D34's second rejected option;
  `test_strike_once_regression_reclassifies_and_passes` pins it). The
  loop moves file; its logic does not move an inch.
- **Do not weaken, renumber, or delete any
  existing test** in `_perf/gate_strike_test.tl`, `_perf/gate_test.tl` or
  `_perf/compare_test.tl`. All 49 pass against the prototype; a red one
  is a defect in the change.
- **Do not touch `.github/workflows/release.yml`, `_perf/run.tl`,
  `_perf/baserun.tl`, `_perf/baseline.tl`, or `_perf/harness.tl`.** The
  gate's CLI, its `--baseline-bin` flag and its one caller
  (`release.yml`) are unchanged, and so is the number of measurement
  passes on the clean path (pass 1 alone) and on the flag-twice path
  (three).
- **Frozen output contracts**: the `perf-compare: PASS` / `perf-compare:
  FAIL` verdict lines, `compare.format_delta`'s row layout and
  `compare.format`'s summary line are parsed downstream — do not change
  them. New text is added only as new `perf-compare:` message lines.
- **Do not widen the 500-line cap, add a lint exemption, or split a file
  beyond `_perf/reproduce.tl`.**
- Do not touch `.cosmic-coverage` except by running the exact regen
  command a coverage-ratchet failure prints, and commit that result.
