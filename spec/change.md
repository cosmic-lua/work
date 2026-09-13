Measured first, on 2026-08-28 against `origin/main@3ff022d3`, because
it decides the shape and **refutes this item's own title**:

- `.github/workflows/release.yml`'s `peers` job declares `needs: build`
  and downloads the artifact the `build` job uploaded.
  `grep -n 'needs:' .github/workflows/release.yml` prints three lines —
  `153` (inside a comment), `260` (`peers`: `needs: build`), `306`
  (`release`: `needs: [build, peers]`).
  `grep -n 'name: cosmic-lua' .github/workflows/release.yml` prints two —
  `239` (the `build` job's `upload-artifact`) and `268` (the `peers`
  job's `download-artifact`). So `./dl/cosmic-lua` at `:295` is the
  CANDIDATE binary, built from this same checkout by this same run, and
  never a published release.
- A cosmic binary embeds `_perf` twice. Against the pinned bootstrap,
  built the same way: `unzip -l o/bootstrap/cosmic | awk '{print $4}' |
  grep -c '^_perf/'` prints `30`, and the same pipeline with
  `grep -c '^\.tl/_perf/'` prints `30`. The peers half is five —
  `unzip -l o/bootstrap/cosmic | awk '{print $4}' | grep '^_perf/peers/'`
  lists `args.lua measure.lua peers.lua report.lua run.lua`, matching the
  five non-test sources `git ls-tree -r --name-only HEAD _perf/peers`
  reports beside two `_test.tl`.
- `/zip/?.lua` and `/zip/.tl` precede the cwd patterns, so a bare run
  answers `_perf.*` from the binary, not the tree. For THIS lane the
  binary's copy IS this checkout's, so instrument and subject agree by
  construction. `3IVF3HbV`, merged as `3ff022d3`, records the same
  finding in its own evidence: "The `peers` job carries no skew and is
  not a reason for anything."

So the question this item was opened to settle — convert the lane, or
leave it — is answered **leave it**. A peers table has ONE cosmic
subject measured against CPython, Node and Go; there is no second cosmic
instrument to hold fixed, and routing it through `_perf/baserun.tl`'s
`--modules` root would add machinery that resolves to identical bytes.
What is missing is not a conversion but a guard: nothing asserts the
peers binary comes from this run, and this item's title is itself the
evidence that a competent reader assumes otherwise.

Two files. No `_perf/**` file is touched.

**1. `.github/workflows/release.yml`** — extend the comment block above
`peers:` (today lines 249-258, ending "the only thing that can fail this
job is a broken cosmic-lua row") with one paragraph recording: the job
runs `_perf/peers/run.tl` bare, so `_perf.*` resolves from the binary's
own `/zip`; that is correct here and only here, because `needs: build`
plus the `cosmic-lua` artifact make the binary this run's own candidate,
so its embedded `_perf` is this checkout's; and it stops being correct
the moment the job takes its binary from a published release instead.
Comment text only — no YAML key, step, or command changes.
`wc -l < .github/workflows/release.yml` is `364` today.

**2. `_build/workflows_test.tl`** — one new helper and one new test.
Measured today: `wc -l < _build/workflows_test.tl` is `352` (148 lines
under the 500-line cap), `grep -c 'local function test_'` is `8`,
`grep -c 'job_body'` is `0`, `grep -c '^test_'` is `0`.

The helper, beside the existing `step_body` — which is step-scoped and
cannot reach the `- uses: actions/download-artifact` step, because that
step carries no `name:`:

```teal
--- @param path string The workflow file
--- @param name string The job's key under `jobs:`
--- @return string The job's lines, including its own `<name>:` line
local function job_body(path: string, name: string): string
```

Scanned line by line — the same technique as `jobs_in` and for the same
reason (a job name may contain `-`, a Lua pattern quantifier): after the
line matching `^jobs:%s*$`, from the line matching `^  <name>:%s*$` up
to but not including the next line matching `^  %S` or `^%S`. `assert`
that the job was found, as `step_body` does for a step.

The test, `test_the_peers_lane_measures_this_runs_own_binary`, defined
and deliberately NOT called: `_build/workflows_test.tl` is a D29
runner-mode file and the runner invokes it. Over
`job_body(WORKFLOWS .. "/release.yml", "peers")` it asserts the body
contains `needs: build`, contains `name: cosmic-lua`, contains
`_perf/peers/run.tl`, does NOT contain `_perf/baseline.tl`, and does NOT
contain `gh release download`; and over
`job_body(WORKFLOWS .. "/release.yml", "build")` that the body contains
`name: cosmic-lua`, closing the loop that the artifact `peers` downloads
is the one `build` uploads. Every needle goes through
`body:find(s, 1, true)` — a literal, per the find-needle lint. Every
assertion message names the path and says what breaks: a peers binary
that is not this run's turns the bare `_perf/peers/run.tl` into a
measurement of a stale harness, silently.

`job_body` must not normalize to a copy of `step_body`: `_build` is in
the dup-body gate's scope (`_build/dupes.tl`'s `TREES`) and that gate is
zero-tolerance. Its differing target pattern and terminator are what
keep it distinct — a constraint to respect, not a refactor to attempt.
