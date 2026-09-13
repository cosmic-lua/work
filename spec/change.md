Two files of product code, two test files, one decision record, one
regenerated index.

1. **`docs/decisions/d31-gate-noise-from-every-control-pair.md`** — a
   new record in the form `skills/decide/SKILL.md` fixes and
   `_build/docs_test.tl` gates: H1 exactly
   `# D31 — the perf gate reads noise from every same-binary pair it
   already measured`, then the `- **date:** 2026-08`,
   `- **status:** active`, `- **context:**`, `- **decision:**`,
   `- **rejected:**` and `- **consequences:**` bullets, matching
   `docs/decisions/d29-tests-run-because-defined.md`'s shape.

   `context` states the hole from `## Evidence` above. `decision`
   states: a scenario's noise credit is the LARGEST same-binary swing
   across every control pair the gate has already measured, not the
   swing in one designated pair; `TRIAGE_K` and the 10% default
   threshold are unchanged. `rejected` names the two options that were
   weighed and lost — raising `--threshold` or adding either scenario
   to a noise-excused set (rejected because it would also excuse
   base64's real +21%), and a committed per-scenario noise profile
   (rejected as premature: it is a fourth committed floor under D27
   with a maintenance cost this hole does not justify, and it can
   still be taken later). `consequences` states plainly what was given
   up: this LOWERS the false-red rate by sampling three pairs instead
   of one, it does not eliminate it — a scenario quiet in all three
   pairs and noisy an hour later still reads as a regression, and the
   remedy for that remains a re-run.

2. **`_perf/compare.tl`** — add `triage_many`, and re-express `triage`
   as a wrapper so all nine existing callers are untouched:

   ```teal
   local function triage_many(base: pt.Results, cur: pt.Results,
       controls: {pt.Results}, threshold_pct?: number): {pt.Delta}, integer
   ```

   It computes `diff(controls[i], controls[j], threshold_pct)` for
   every unordered pair `i < j`, and builds `self_by_name` keyed on
   scenario name holding, per scenario, the entry with the largest
   `math.abs(delta_pct)` among pairs where that scenario's verdict was
   `regression` or `faster`. The reclassification test below it is the
   existing one, unchanged, including `TRIAGE_K`. Fewer than two
   controls means no pairs and no reclassification — identical to
   today's behaviour when the A/A is absent.

   `triage(base, cur, na, nb, t)` becomes
   `return triage_many(base, cur, {na, nb}, t)`. Export `triage_many`
   on the module record beside `triage` (the record at
   `_perf/compare.tl:294-303` and the table at `305-315`).

3. **`_perf/gate.tl`** — teach the triage step to pass all three
   same-binary files. At lines `169-171`, replace the
   `compare_once(..., retry, opts.selfcheck_b)` call with a call that
   loads `opts.current`, `retry` and `opts.selfcheck_b` and passes
   them as `controls` to `compare.triage_many`. `opts.current` joins
   the control set ONLY when `identity_refusal(retry, opts.current,
   true)` returns nil; when it does not, drop `opts.current` from the
   controls silently and carry on with the other two — a mismatched
   binary is a bonus control lost, not a new refusal, and today's
   behaviour is what remains. The existing
   `identity_refusal(retry, opts.selfcheck_b, true)` check at line
   `164` stays exactly as it is and still refuses.

   Extend `compare_once`'s optional-control parameters, or add a
   sibling helper beside it — either shape is fine as long as
   `compare_once`'s existing two-control call at line `77` keeps its
   signature and its `_perf/run.tl:354` counterpart is untouched.

4. **`_perf/compare_test.tl`** — add two test functions, each called
   on the line after its `end` per AGENTS.md:

   - `test_the_loudest_control_pair_sets_the_noise_credit` — three
     controls where the scenario is quiet in one pair and swings in
     another; assert the regression reclassifies to `noise` and
     `failures` drops by one. Build it from `3ISWHyP7`'s real
     `json_decode_large` numbers: baseline `798.63` µs, current
     `891.35` µs (+11.6%), controls at `1210`, `1360` and `1215`
     ns-scaled so one pair reads ~+12.6% and another ~+0.4%.
   - `test_a_real_regression_survives_every_control_pair` — the
     `codec_base64_roundtrip_64k` case: baseline `132.05` µs, current
     `159.82` µs (+21.0%), three controls within 4.8% of each other.
     Assert the verdict stays `regression` and `failures` is
     unchanged. This is the test that proves the change did not break
     the gate.

5. **`_perf/gate_test.tl`** — add one test function,
   `test_the_gate_triages_against_every_measured_control`, called on
   the line after its `end`: drive `gate` through its full
   retry-then-selfcheck path with a `measure` stub whose successive
   writes make `current` vs `selfcheck_b` the loud pair and `retry`
   vs `selfcheck_b` the quiet one, and assert the gate exits `0`. It
   fails before change (3) and passes after.

6. **Regenerate the decisions index**: `bin/cosmic _docs/derive.tl`
   rewrites the derived table in `docs/decisions/README.md`, which
   `_build/docs_test.tl` gates. Commit the rewritten README. If any
   ratchet gate complains, run exactly the regen command its failure
   message prints and commit that result — never weaken a gate any
   other way.
