- **Do not change the `same = false` behaviour.** A pair where one side
  has no stamp still warns and still compares. `run.tl --compare` over an
  archived pre-#1432 results file must keep working
  (`_perf/run.tl:333-334` passes `same = false`), and
  `test_a_file_without_a_sha_is_not_refused` must keep passing unedited.
- **Do not make `run.tl` refuse to write a stampless results file**, and
  do not change how `meta.bin` / `meta.bin_sha` are derived
  (`_perf/run.tl:118-147`). That is a separate question and belongs to
  `3IVEEDO8`.
- **Do not touch `TRIAGE_K`, `DEFAULT_THRESHOLD_PCT`, `diff`, `triage`,
  `triage_many`, or `loudest_control`.** D31 froze `compare.triage`'s
  signature and fixed `TRIAGE_K = 2` and the 10% bar
  (`_perf/compare.tl:19` and `:27` today); this slice changes WHICH runs
  may be controls, never how much credit a control buys.
- **Do not weaken any scenario, functional check, or existing
  assertion.** Every expected exit code in `_perf/gate_test.tl` stays as
  it is; the only edit there is adding a stamp argument and moving two
  trailing comments.
- **Do not touch `_perf/run.tl`, `_perf/baseline.tl`, `_perf/baserun.tl`,
  `_perf/harness.tl`, `_perf/stats.tl`, `_perf/peers/**`,
  `_perf/bench/**`, `.github/workflows/release.yml`, or
  `skills/optimize/**`.** No lane's commands change. `_perf/peers/**`
  carries its own `cosmic_bin_sha` field and never reaches
  `compare.identity_refusal` (`grep -rln 'identity_refusal' _perf/`
  returns only `compare.tl`, `gate.tl`, `run.tl`, `gate_test.tl`,
  `gate_strike_test.tl`) — it is a different report, out of scope.
- **Do not touch `_perf/gate_strike_test.tl`** (step 6: already stamped)
  **and do not restructure `_perf/gate_test.tl`** beyond the five
  stamped fixtures and the two moved comments.
- **Do not commit anything under `o/perf/`,** and do not run the real
  `_perf` harness for this slice: nothing here is a timing claim, every
  test injects `measure`, and `3IU0GxoA` established that absolute
  readings are not comparable across sessions anyway.

**What this does NOT license.** This slice makes an existing precondition
non-vacuous. It is not permission to touch the arithmetic that
precondition guards, and specifically not any of the following, none of
which it needs:

- **No threshold, floor or bar is created, widened, or moved.** The only
  committed number of that kind is `DEFAULT_THRESHOLD_PCT = 10.0`
  (`_perf/compare.tl:19`), with `TRIAGE_K = 2.0` (`:27`), and no
  scenario module carries a per-scenario floor:
  `git grep -nE 'noise_floor|threshold_pct *=' -- _perf/bench` returns
  no matches on `origin/main` today. `3ISlY5Xl` held a release at
  `21.0 > max(10.0, 2 × 4.8)` — that arithmetic is what makes the gate
  honest, and a widened floor retires it. If a test in this slice needs
  a different bar to make its point, change the FIXTURE numbers, never
  the committed constant.
- **No row's classification rule moves.** The slice changes which runs
  may enter the `controls` list, not how `triage_many` weighs the list.
- **The `noise` verdict is not being made cheaper to earn.** Every one
  of the four new tests asserts `code == 1` — the direction of this
  change is strictly toward failing, never toward passing.
- **Nothing here licenses re-running or re-litigating a perf number.**
  No measurement in this spec is a timing measurement.

**Serialization with PR #1485 (`3IUBNQZZ`, `check`).** The two are
merge-clean as specified (measured above), so neither blocks the other
and no `blocked_by` edge is warranted. But both touch
`_perf/compare.tl`'s `record compare` / `M` block and both insert a
helper into `_perf/gate.tl`, so whichever lands second must re-run
Acceptance 8 after rebasing, and must re-check the 500-line cap on
`_perf/gate.tl` (491 combined — 9 lines of headroom).

**Relation to `3IWx3I4Z` (`backlog`, unrefined).** It wants a SECOND
control group in `triage_many` so the baseline pair earns noise credit,
and its own spec says it needs `loudest_control` and `triage_many` —
which this slice's `Non-goals` forbid touching. Its edit region in
`_perf/gate.tl` is the same `local controls = {retry, opts.selfcheck_b}`
block this slice edits at `:265-268`. This slice is the smaller and
earlier change and should land first; `3IWx3I4Z` rebases onto
`same_binary` when it is refined. No edge is filed: `3IWx3I4Z` is not
blocked by this (it could be written either way) and this is not blocked
by it.

**Relation to `3IVEEDO8` (`plan`, blocked by `3IUBNQZZ`).** Adjacent
subject, disjoint code. It prints `meta.timestamp` in a report header and
its Change lands in `_perf/perf_types.tl`, `_perf/run.tl`'s
`RESULTS_SPEC`, and the header `3IUBNQZZ` introduces. This slice touches
none of those and reads `meta.bin_sha` only. The one shared fact is that
both are about `meta` identity, which is a reason to keep the Non-goal
above pointing at `3IVEEDO8` — not a reason for an edge.
