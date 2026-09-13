Make the release's existing perf compare refuse a regressing release. The measurement
and publication half landed with #1121: `release.yml` measures the release binary
(release.yml:120-127), fetches the previous release's `perf.json`
(`_perf/baseline.tl`), runs `_perf/gate.tl compare`, and publishes `perf.json` +
`compare.txt` as release assets. The compare's verdict is currently thrown away twice
over: the gate's exit status reaches the step through `| tee o/perf/compare.txt`, and a
pipeline's status is `tee`'s, and then a trailing `exit 0` (release.yml:152) discards
whatever survives. Two files change; `_perf/**` does not.

The baseline exists now: release `2026-08-17-a3cd318` carries a `perf.json` asset (43
scenarios, none errored), and `_perf/baseline.tl` selects it by rule. The gate's noise
policy is `_perf/gate.tl`'s existing one, unchanged and unparameterised — the default
10% bar widened per scenario to the larger of the two runs' observed spread
(`_perf/compare.tl:97`), one automatic re-measure, then an A/A self-check on the same
runner in the same job that reclassifies a swing the binary reproduces against itself
as `noise` (`_perf/gate.tl:116-163`, `TRIAGE_K` at `_perf/compare.tl:26`). Because the
A/A control is measured on the release runner itself, no release-runner-specific margin
and no historical calibration is introduced.

**1. `.github/workflows/release.yml`**

- In `on.workflow_dispatch.inputs`, after `prerelease`, add:

  ```yaml
      perf_gate:
        description: 'Fail the release on a perf regression'
        required: false
        type: boolean
        default: true
  ```

- On the "compare against the previous release" step (release.yml:136-152), add to the
  step's existing `env:` block, beside `GH_TOKEN`:

  ```yaml
          PERF_GATE: ${{ github.event.inputs.perf_gate == 'false' && 'false' || 'true' }}
  ```

  A cron fire has no inputs, so `PERF_GATE` is `true` there: scheduled releases always
  gate, and only an explicit dispatch with the box cleared turns the gate off.

- Replace that step's `run:` block with exactly this, keeping the `runuser -u builder`
  + `env HOME=… PATH=…` pattern of its neighbours:

  ```yaml
        run: |
          set -ux
          rc=0
          runuser -u builder -- env HOME="$HOME" PATH="$PATH" GH_TOKEN="$GH_TOKEN" \
            bash -eo pipefail -c '
            o/bin/cosmic --make run _perf/baseline.tl --repo ${{ github.repository }} \
              --out o/perf/prev/perf.json | tee o/perf/baseline.txt
            if grep -q "^perf-baseline: SKIP" o/perf/baseline.txt; then
              echo "perf-compare: SKIP (no baseline: first measured release)" > o/perf/compare.txt
            else
              o/bin/cosmic --make run _perf/gate.tl compare \
                o/perf/prev/perf.json o/perf/perf.json o/perf/selfcheck.json \
                | tee o/perf/compare.txt
            fi' || rc=$?
          if [ "$rc" -ne 0 ]; then
            [ -f o/perf/compare.txt ] && cat o/perf/compare.txt >&2
            tail -n1 o/perf/baseline.txt >&2
            echo "perf gate: this release regressed against the previous one and was not published." >&2
            echo "  re-run the release workflow to re-measure: a real regression reproduces, noise does not." >&2
            echo "  if it reproduces, work it under skills/optimize/SKILL.md; never weaken a scenario or its check()." >&2
            echo "  after a deliberate scenario rename or removal, re-baseline by dispatching this workflow once with perf_gate: false." >&2
            if [ "$PERF_GATE" = "true" ]; then exit "$rc"; fi
            echo "perf gate: DISABLED by workflow input — regression reported, not enforced." >&2
          fi
  ```

  Three edits are load-bearing and each is required on its own: `bash -eo pipefail -c`
  (without `pipefail` the compare's status is `tee`'s and the gate stays decorative),
  the deletion of the trailing `exit 0` at release.yml:152, and `set -ux` rather than
  `set -eux` on the outer shell so `rc` can be captured. The `exit 0` at
  release.yml:187 belongs to the size step and stays.

- Replace the report-only paragraph of that step's comment (release.yml:129-135) with
  what the gate now means: a `perf-compare: FAIL` verdict fails the `build` job, so the
  `release` job (`needs: build`) never runs and a regressing release publishes no
  assets — which is the ratchet's point, because the baseline then stays the last
  release that passed. A `perf-baseline: FAIL` (network or API failure) fails the step
  too; the next cron fire retries. `perf-compare: SKIP (no baseline)` still succeeds.
  Record that `perf_gate: false` on a dispatch is the one way to publish a new baseline
  when the scenario set legitimately changed — `_perf/compare.tl:115-121` counts a
  scenario present in the baseline and missing from the current run as a failure, so a
  rename with the gate on would block every later release too.

**2. `_build/workflows_test.tl`** — the verdict can be re-swallowed by a one-token
edit, so ratchet it where the other workflow pins are ratcheted. Add a `step_body(path,
name): string` helper (scan from the line whose trimmed text is `- name: ` to the
next line at that same indentation, the same line-scanning technique `jobs_in` uses and
for the same reason: step names contain `-`) and one test,
`test_the_release_perf_compare_propagates_its_verdict`, over the body of
`.github/workflows/release.yml`'s "compare against the previous release" step,
asserting that it:

- contains `pipefail` — with a message saying that the compare's status arrives through
  `| tee` and a pipeline's status is `tee`'s;
- contains `exit "$rc"` — the step propagates the compare's exit code;
- contains no `|| true` and no `continue-on-error`;
- still contains `perf-compare: SKIP` — the bootstrap path stays a pass.

Measured headroom against the 500-line file cap, and the pre-change values of every
count the Acceptance greps:

```facts
$ wc -l < .github/workflows/release.yml
251
$ wc -l < _build/workflows_test.tl
278
$ grep -n 'exit 0' .github/workflows/release.yml
152:            exit 0'
187:            exit 0'
$ grep -c pipefail .github/workflows/release.yml
1
$ grep -c perf .github/workflows/pr.yml
1
$ grep -n 'DEFAULT_THRESHOLD_PCT = 10.0' _perf/compare.tl
18:local DEFAULT_THRESHOLD_PCT = 10.0
$ grep -n 'TRIAGE_K = 2.0' _perf/compare.tl
26:local TRIAGE_K = 2.0
$ grep -n 'perf-compare: FAIL' _perf/gate.tl
94:    print("perf-compare: FAIL")
$ ls _perf/bench | wc -l
17
```
