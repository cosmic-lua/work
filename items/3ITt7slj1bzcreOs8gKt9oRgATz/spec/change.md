Three files: the gate, its tests, and the workflow's one invocation
line. The decision, in one sentence: **a flagged regression fails the
gate only when it strikes in BOTH passes, and the retry re-measures
BOTH binaries so a single unlucky reading on either side cannot
anchor the verdict.**

### `_perf/gate.tl`

1. `compare_once` also returns its `{pt.Delta}` list (third return —
   slot 1 is `integer`, not nil-admitting, so the fallible-returns
   rule does not bind).
2. `GateOptions` gains `measure_baseline: Measure` (optional field —
   nil when the caller cannot re-run the baseline binary).
3. `gate_inner`, after pass 1 (`diff(base, current)`) flags failures:
   - record `R1 = {name | verdict == "regression"}` from pass 1;
   - measure the current retry as today; when `measure_baseline` is
     set, also measure the baseline retry into
     `retry_path(opts.baseline)` and use THAT as the base side of
     pass 2 and of the final triage — with two identity checks: the
     baseline retry names the SAME binary as the baseline
     (`identity_refusal(base, base_retry, true)`), and pass 2's pair
     still names DIFFERENT binaries;
   - pass 2 and the final triaged pass proceed as today (early return
     0 when the retry compare is clean; controls harvested as today —
     controls are current-binary runs and are unaffected by the
     baseline side);
   - at the FINAL judgment, any delta with `verdict == "regression"`
     whose name is NOT in `R1` reclassifies to `"noise"` with the
     failure count decremented, BEFORE the table is printed — the
     printed table is the record and must show the verdict the gate
     acted on. Print one line naming each strike-once reclassification
     (`perf-compare: <name> flagged only in the retry — not
     reproduced, counted as noise`). `error`/`missing`/
     `baseline-error`/`malformed` verdicts never reclassify.
   - Update the module doc comment: the header's "noise must strike
     twice" sentence now describes what the code does, and says the
     baseline retry exists because a single baseline reading
     otherwise anchors every pass.
4. `main`: accept `--baseline-bin PATH` in the option loop; when
   given, build `measure_baseline` as: run `PATH _perf/run.tl --out
   OUT <runargs...>` via `cosmic.child.run`, returning the exit code
   — the EXACT invocation shape `release.yml:173` uses for the
   baseline measure, so script-mode module resolution is identical.
   Update the usage text.

### `_perf/gate_test.tl`

Four tests, in the file's fabricated-results style (multi-scenario
results files where needed — `write_results` may need a variant
taking a list; keep the file under 500 lines):

- strike-once reclassifies: pass 1 flags scenario A only, the retry
  is clean for A but flags scenario B → gate PASSES, B's final
  verdict is noise;
- strike-twice still fails: the same scenario flags in pass 1 and in
  the final triaged pass → gate FAILS (the regression-detection tooth
  is intact — this is the regression test for the gate itself);
- the baseline retry is used when `measure_baseline` is set: a bad
  one-off baseline reading (base file slow-biased) with a clean
  baseline retry → gate PASSES, and the baseline retry file exists at
  `retry_path(baseline)`;
- a baseline retry naming a DIFFERENT binary than the baseline is
  refused (identity guard).

Existing seventeen tests pass unchanged except where a signature
ripples (`compare_once` is local — no test calls it; `GateOptions`
gains an optional field — existing literals stay valid).

### `.github/workflows/release.yml`

The gate invocation (`:174-176`) gains `--baseline-bin
o/perf/prev/cosmic-lua`. Nothing else in the workflow moves; the
`perf_gate: false` escape and all step comments stand. NOTE: pushing
a `.github/workflows/**` change may be refused if the credential
lacks the `workflows` permission — if the push is rejected for that
reason, land the gate+tests without the workflow line, and file the
one-line workflow edit as its own item for a human push; the gate
change is compatible with the flag absent.
