The defect, verified against `origin/main@6a4d0182` (line numbers are that
tree's). `gate_inner` builds `flagged_first` at `_perf/gate.tl:152-157` from
pass 1's deltas, judged against `opts.baseline`. When `opts.measure_baseline`
is set it then re-measures the baseline into `base_side` (`gate.tl:170`) and
judges passes 2 and 3 against THAT file. The strike-twice loop
(`gate.tl:242-249`) compares those two flag sets — so it asks whether the
regression reproduced against a MOVING reference. A scenario whose pass-1
baseline reading was one-off SLOW is masked in pass 1, flags in pass 2 against
the honest retry, survives triage with quiet controls, and is then discarded at
`gate.tl:243` as "flagged only in the retry -- not reproduced".

Reproduced end to end through `gate.gate` on `origin/main`, base
`{a=1000, b=1300}`/`aaaa1111` against current `{a=1300, b=1300}`/`bbbb2222`,
`measure` writing `{a=1000, b=1300}` and `measure_baseline` writing
`{a=1000, b=1000}`:

```
b                                 1.00 µs ->      1.30 µs    +30.0%  (noise  ±10.0%)  regression
perf-compare: regression persists; running A/A self-check to separate real regressions from machine noise
perf-compare: b flagged only in the retry -- not reproduced, counted as noise
b                                 1.00 µs ->      1.30 µs    +30.0%  (noise  ±10.0%)  noise
2 scenarios: 0 regression, 0 faster, 1 ok, 1 noise, 0 new, 0 missing, 0 error, 0 baseline-error, 0 malformed
perf-compare: PASS
```

Four files.

**1. `_perf/gate.tl` — re-key the strike-twice rule to the baseline the
failing judgment already uses.** After the baseline retry and its
`identity_refusal(opts.baseline, base_side, true)` check (after `gate.tl:184`)
and before the `identity_refusal(base_side, retry, false)` check at
`gate.tl:189`, add a guarded block: when `base_side ~= opts.baseline`,
recompute `flagged_first` from `compare_once(base_side, opts.current,
opts.threshold)` — the caller's own pass-1 CURRENT file judged against the
RE-MEASURED baseline — replacing the table built at `gate.tl:152-157`. Handle a
negative failure count exactly as the other `compare_once` call sites do
(`io.stderr:write(tostring(err) .. "\n"); return 1`). No new measurement: both
files are already on disk. The rule then reads what it always meant — two
INDEPENDENT current-side samples flagging against ONE common baseline.

The guard is load-bearing: when `opts.measure_baseline` is nil, `base_side ==
opts.baseline`, the block does not run, and behaviour is unchanged for every
invocation without `--baseline-bin`. `--baseline-bin` has exactly one caller:
`git grep -n -- "--baseline-bin" -- .github _perf` on `origin/main` returns
`.github/workflows/release.yml:184` plus `_perf/gate.tl`'s own usage and
argument-parsing lines and nothing else.

Also rewrite the module header comment (`gate.tl:2-13`) to state the rule as it
now is, and to state the sampling asymmetry it does NOT fix: a regression that
reads quiet on the retry ends the gate at `gate.tl:200-202` with two
current-side samples and no A/A control, while one that flags twice gets a
third sample and triage across three control pairs. That asymmetry is captured
as `3IWU4i0l` and is out of scope here.

Measured: `git show origin/main:_perf/gate.tl | wc -l` = 406. The prototyped
change is +23 lines (429) before the header rewrite.

**2. `_perf/gate_test.tl` — split, to make room.** `git show
origin/main:_perf/gate_test.tl | wc -l` = 479, twenty-one lines under the
500-line cap, so the new tests cannot land in it. Move lines 381-479 verbatim —
the blank line, the strike-twice comment block, and the four tests
`test_strike_once_regression_reclassifies_and_passes`,
`test_strike_twice_regression_still_fails`,
`test_baseline_retry_rescues_a_one_off_baseline_reading`,
`test_baseline_retry_naming_a_different_binary_is_refused` — into a new
`_perf/gate_strike_test.tl`. That leaves `_perf/gate_test.tl` at 380 lines with
17 test functions.

**3. `_perf/gate_strike_test.tl` — the new file.** It repeats
`gate_test.tl`'s preamble (lines 1-38: shebang, doc comment, requires,
`write_multi`, `write_results`, `paths`) with its own doc comment naming the
strike-twice rule and the baseline retry, and WITHOUT the `check` and `compare`
requires — the moved tests use neither, and `gate_test.tl` keeps both because
`test_retry_does_not_overwrite_current` still calls `check.must` and
`compare.load_results`. Follow the file's existing shape: `test_*` functions are
defined and not called; the runner extracts them (it reported 21 for
`gate_test.tl`). Add three tests, all in the injected-measure style, all
prototyped and passing:

- `test_masked_baseline_regression_still_fails` — the escape above, asserting
  the gate exits 1. This is the test that FAILS on `origin/main`'s gate.
- `test_a_one_off_fast_baseline_retry_fails_the_gate` — the mirror: base
  `{a=1000, x=1000}`/`aaaa1111`, current `{a=1300, x=1000}`/`bbbb2222`,
  `measure` writing `{a=1000, x=1000}`, `measure_baseline` writing
  `{a=1000, x=700}`. `x` is steady on every current-side run and the baseline
  RETRY is the one-off, so both current samples now flag against it and the gate
  exits 1 where it used to exit 0. This pins the accepted cost of the change,
  and it also fails on `origin/main`'s gate.
- `test_current_side_instability_absorbs_the_fast_baseline_retry` — the same
  numbers except the second `measure` call writes `x = 1300`. The A/A control's
  +30% swing gives TRIAGE_K credit covering the +42.9% flag, so the gate exits 0.
  This is the guard on the cost above, and it passes both before and after.

Measured: with the move and the three tests the file is 212 lines.

**4. `docs/decisions/dNN-<slug>.md`, plus the regenerated index.** This
changes a release gate's sampling rule and gives something up, so it earns a
record under `skills/decide`. Take the next free number by `ls docs/decisions/`
on the branch cut from latest `origin/main`: `d32` is the highest on main today
and `d33` is already claimed by an in-flight branch
(`origin/claude/3IWJ2cHm-metatable-value-type`), so check at branch time and
renumber if that lands first. H1, exactly: `# D<n> — the perf gate judges
reproduction against the re-measured baseline`. Then `bin/cosmic
_docs/derive.tl` to rewrite the index table in `docs/decisions/README.md`.

The record's four sections, decided here:

- **context** — the escape above with its gate output; that `release.yml`
  re-baselines to the previous release's BINARY daily, so one escape is absorbed
  into the ratchet permanently and never re-asked; and the machine evidence that
  a one-off per-scenario reading is routine on either side. That evidence,
  re-measured at pull, 2026-08-28, in one container:
  `bin/cosmic --make run _perf/gate.tl selfcheck A.json B.json` over the full
  suite reported `48 scenarios: 12 regression, 1 faster, 35 ok, 0 noise, 0 new,
  0 missing, 0 error, 0 baseline-error, 0 malformed` — 13 of 48 scenarios move
  past the 10% bar with the SAME binary measured twice back to back, up to
  +95.1% (`sqlite_point_query`), +33.1% (`stream_lines_iterate`), +31.0%
  (`re_match_log_line`). The refine-time reading of the same command at
  `origin/main@6a4d0182` was 14 of 48, loudest +62.2% (`re_split_colon_list`):
  the shape is stable, the individual scenarios and magnitudes are not, which is
  itself the evidence the record cites.
- **decision** — the reproduction rule reads ONE baseline, the re-measured one,
  and asks two independent current-side samples about it. `TRIAGE_K` and the
  default bar are untouched.
- **rejected**, each with the reason it lost:
  - *keep pass 1's flags as measured.* The losing option a competent
    contributor would pick: requiring the flag against BOTH baseline readings
    suppresses strictly more noise, and a false red is the failure
    `skills/optimize/measurement.md` calls expensive. It loses because the two
    errors are not symmetric in cost — a false red costs one workflow re-run,
    while the false green it produces is absorbed into the next release's
    baseline and can never be re-asked.
  - *count a regression flagging in EITHER pass (the union).* Reinstates the
    false red the strike-twice rule was added to remove — a scenario flagging
    only in the retry from CURRENT-side variance, which
    `test_strike_once_regression_reclassifies_and_passes` pins.
  - *also give the baseline pair its own noise credit.* `opts.baseline` and
    `base_side` measure the same binary by construction (the gate enforces it at
    `gate.tl:179`), so their disagreement is a legitimate A/A control that would
    absorb the mirror false red directly. Correct, and better — rejected here as
    a separate slice, because `_perf/compare.tl`'s `loudest_control` is not
    exported and adding the pair to the existing `controls` list would form
    baseline-vs-current pairs, which is the comparison under test; it needs
    `triage_many` to take a second control GROUP. Rejected as premature, not
    forever: the measured evidence is that a scenario unstable enough to produce
    a one-off baseline reading is normally unstable on the current side too,
    where the existing credit already absorbs it — which is exactly what
    `test_current_side_instability_absorbs_the_fast_baseline_retry` shows.
- **consequences** — names the cost in the false-positive direction (the
  residue: a scenario quiet across all three current-side control pairs whose two
  baseline readings disagree past the bar now fails where it used to pass), the
  remedy `release.yml` already prints for a false red ("re-run the workflow"),
  and what would make us revisit (repeated reds traceable to the baseline retry
  — then buy the baseline-pair credit above).
