- Do not change `TRIAGE_K`, `DEFAULT_THRESHOLD_PCT`, `loudest_control`,
  `triage`, `triage_many` or anything else in `_perf/compare.tl`.
  D31 (`docs/decisions/d31-gate-noise-from-every-control-pair.md`) governs
  how much variance a scenario is credited for and stands unamended; this change
  is only about WHICH baseline the reproduction rule reads.
- Do not add a measurement pass anywhere. The re-key reads two files the gate
  has already written; a fix that costs runs inside `release.yml`'s
  15-minute-timeout step is a different change.
- Do not touch `_perf/gate.tl:200-202`, the quiet-pass-2 early return. State the
  asymmetry in the header comment; the fix is captured as `3IWU4i0l`.
- Do not touch `.github/workflows/release.yml`, `skills/optimize/SKILL.md` or
  `skills/optimize/measurement.md`. PR #1480 (item `3IVF3HbV`) is in flight over
  the first two; the third is its neighbour and not needed for this change.
- Frozen contracts: the `perf-compare: PASS` / `perf-compare: FAIL` verdict
  lines, `compare.format`'s summary line, and the `perf-compare: <name> flagged
  only in the retry -- not reproduced, counted as noise` line — `release.yml`
  tees and greps this output.
- Do not rename, remove or weaken a scenario or its `check()`.
  `_perf/compare.tl` counts a baseline scenario missing from the current run as
  a failure, so a rename blocks every later release.
- Do not hand-edit the table under `| # | decision | status | |` in
  `docs/decisions/README.md`; `_docs/derive.tl` owns those rows.
- Do not commit anything under `o/perf/`.
