- **Do not give the baseline pair a noise credit, and do not add a second
  control GROUP to `triage_many`.** That is the instrument this item
  disproves. No baseline-versus-current pair is formed anywhere.
- **Do not change `TRIAGE_K`, `DEFAULT_THRESHOLD_PCT`, `diff`'s verdict
  vocabulary, `loudest_control`, `triage_many`, `format`, `format_delta`,
  `format_identity`, `load_results` or `same_binary`.** `_perf/compare.tl`
  is READ by this change and not edited. D31 governs how much variance a
  scenario is credited for and stands unamended; this change creates no
  credit at all.
- **Do not touch the current side.** The retry, the A/A self-check, the
  three control pairs, `flagged_first`'s re-key and the strike-twice loop
  keep their exact behaviour. `3IWU4i0l` owns the current-side sampling
  question and lands first.
- **Do not change the number of passes on the clean path, or on a run
  whose two baseline readings agree.** Both stay exactly what they are
  today. The third pass is conditional and that is the point.
- **Do not touch `.github/workflows/release.yml`, `_perf/run.tl`,
  `_perf/baserun.tl`, `_perf/baseline.tl` or `_perf/harness.tl`.** The
  gate's CLI, its `--baseline-bin` flag and its one caller
  (`release.yml:188`) are unchanged; `grep -c 'baseline-bin'
  .github/workflows/release.yml` is 1 before and after.
- **Frozen output contracts**: the `perf-compare: PASS` / `perf-compare:
  FAIL` verdict lines, `compare.format_delta`'s row layout and
  `compare.format`'s summary line are parsed downstream. New text is added
  only as new `perf-compare:` message lines. The existing
  `perf-compare: re-measuring the baseline into ...` line keeps its
  wording when it moves into `_perf/tiebreak.tl`.
- **One behaviour change, deliberate and pinned:** a failed baseline
  re-measurement now exits 1 with a printed message instead of
  propagating the runner's own exit code. `release.yml` branches on
  nonzero, so it is unobservable at the one caller, no test covered it,
  and `test_a_failed_measurement_is_reported` pins it. The CURRENT-side
  `measure` rc still propagates unchanged —
  `_perf/gate_test.tl:test_measure_failure_propagates` must stay green.
- **Do not widen the 500-line cap, add a lint exemption, split
  `_perf/gate.tl`, or fold `3IYCQxfH` in.** The change is designed to
  leave `_perf/gate.tl` smaller than it found it.
- **Do not weaken any scenario, its `check()`, or its numbers.** No
  per-scenario floor, no per-bench opt-out, no widened default bar.
- Do not touch `.cosmic-coverage` except by running the exact regen
  command a coverage-ratchet failure prints
  (`bin/cosmic --make coverage --baseline`), and commit that result.
