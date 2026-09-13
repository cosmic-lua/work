Four decisions are settled below and written into the diff; nothing here is left to
the implementer's judgement.

**Settled: seed policy.** One seed per run, from the WORKFLOW env, never from a clock
read inside a test: the lane computes `FUZZ_SEED` as `date -u +%Y%m%d` (a rotating
integer, e.g. `20260817`), overridable by a `workflow_dispatch` input for replay. Every
module in a run gets the same seed, so ONE line reproduces the whole lane. The seed is
recorded three times: a `deep-fuzz: seed= iters=` line on stdout before the run,
the same line plus a copy-pasteable reproduce command in `$GITHUB_STEP_SUMMARY`, and
`seed=` inside any driver failure message (`_fuzz/driver.tl:66-69`). Tests stay
deterministic given their environment, and the declared-env stamp from #1156 makes that
environment a real cache input.

**Settled: failure routing.** The lane fails loudly and the run is the artifact: no
auto-filing, no comment, no `issues: write`. The driver's message already carries
`seed=`, `iteration=` and `input(base64)=`, the step summary carries the reproduce
command, and `o/_fuzz/*.test.err`/`.out`/`.time` upload as an artifact so the failing
input survives log truncation. Dedup is structural — one scheduled run per day means one
notification stream, not N issues. Auto-filing was rejected: it needs a write-scoped
token in a lane that runs arbitrary tree code, a board `comment` verb that does not exist
(#1204, still `work:plan`), and a dedup key nobody has designed. Turning a finding into a
regression test stays a human/agent step, which is G5's other measure.

**Settled: budget.** One uniform `FUZZ_ITERS=50000` for the whole lane (195x the 256
default), `2000` on the pull_request trigger. Uniform rather than per-module because
`_fuzz/driver.tl:81` reads a single `FUZZ_ITERS`, and `_make/envstamp.tl:73-88` writes
every declaring file's stamp on every invocation regardless of selection — so per-module
values would invalidate the modules run under a different value and re-execute them for
nothing. Depth chosen to clear the deepest real find by a margin: the url `format`
fixpoint property first failed at iteration 18,602 (#1156's evidence), and 50,000 gives
2.7x headroom. Measured on the refinement host (`o/bin/cosmic` at `a3cd318`, one module
per process, `FUZZ_SEED=20260817`) — host-dependent, so not a facts-block claim:

| module | 2,000 iters | 20,000 iters | 50,000 iters |
|---|---|---|---|
| compress | 1,739 ms | 15,810 ms | 38,463 ms |
| json | 105 ms | 1,106 ms | 2,638 ms |
| re | 245 ms | 2,384 ms | 5,458 ms |
| sse | 357 ms | 3,608 ms | 8,373 ms |
| tar | 3,263 ms | 37,836 ms | 82,376 ms |
| url | 289 ms | 2,647 ms | 6,264 ms |
| **total** | **5,998 ms** | **63,391 ms** | **143,572 ms** |

Linear in `FUZZ_ITERS` (10x iterations, 10.6x time), all six green at 50,000. The whole
suite is 2.4 minutes of property time here and `tar` is 57% of it; at a 4x derate for a
shared runner that is ~10 minutes, plus fetch and the converging build. Hence the caps:
`timeout-minutes: 30` on the deep step and `timeout-minutes: 45` on the job — the lane
finishes or dies loudly, and a future property that turns superlinear hits a timeout
instead of hanging.

**Settled: placement.** A dedicated `.github/workflows/fuzz.yml` with its own cron, NOT
a step in `release.yml`. `release.yml`'s `build` job is one `set -eux` chain feeding
`release`, so a deep-fuzz step there either fails the release (a fuzz find must never
block shipping) or is guarded with `|| true` (a lane that cannot fail is not a lane).
Its own workflow also gets its own cadence, its own timeout, its own concurrency group,
and read-only permissions.

```facts
$ ls -1 _fuzz/*_fuzz_test.tl
_fuzz/compress_fuzz_test.tl
_fuzz/json_fuzz_test.tl
_fuzz/re_fuzz_test.tl
_fuzz/sse_fuzz_test.tl
_fuzz/tar_fuzz_test.tl
_fuzz/url_fuzz_test.tl
$ ls -1 _fuzz/*_fuzz_test.tl | wc -l
6
$ grep -c "driver.run({" _fuzz/*_fuzz_test.tl
_fuzz/compress_fuzz_test.tl:3
_fuzz/json_fuzz_test.tl:3
_fuzz/re_fuzz_test.tl:3
_fuzz/sse_fuzz_test.tl:3
_fuzz/tar_fuzz_test.tl:3
_fuzz/url_fuzz_test.tl:4
$ grep -n "DEFAULT_ITERS\|DEFAULT_SEED" _fuzz/driver.tl
19:local DEFAULT_SEED = 1
20:local DEFAULT_ITERS = 256
80:  local seed = env_integer("FUZZ_SEED", DEFAULT_SEED)
81:  local iters = opts.iters or env_integer("FUZZ_ITERS", DEFAULT_ITERS)
$ grep -rl "^--- env:" _fuzz/
_fuzz/sse_fuzz_test.tl
$ ls -1 .github/workflows/
docs.yml
pr.yml
release.yml
$ grep -c "image: buildpack-deps@sha256:cfb30ff3856780c63b00ec3ad2e4aed77ae6afce5975ebb8ad9525ec45354e2e # noble (Ubuntu 24.04)" .github/workflows/docs.yml .github/workflows/pr.yml .github/workflows/release.yml
.github/workflows/docs.yml:1
.github/workflows/pr.yml:3
.github/workflows/release.yml:1
$ wc -l _fuzz/compress_fuzz_test.tl _fuzz/json_fuzz_test.tl _fuzz/re_fuzz_test.tl _fuzz/tar_fuzz_test.tl _fuzz/url_fuzz_test.tl
  143 _fuzz/compress_fuzz_test.tl
  166 _fuzz/json_fuzz_test.tl
  246 _fuzz/re_fuzz_test.tl
  305 _fuzz/tar_fuzz_test.tl
  291 _fuzz/url_fuzz_test.tl
 1151 total
```

1. **`.github/workflows/fuzz.yml`** (new, one job, ~90 lines including comments).
   `docs.yml` is the skeleton — single containerised job, prepare-builder, fetch, run:
   - Triggers: `schedule: - cron: '0 9 * * *'` (daily, three hours after release.yml's
     `0 6 * * *`, so the two lanes never contend and a find lands on a tree that already
     shipped); `workflow_dispatch` with two string inputs, `seed` and `iters`, both
     defaulting to `''`; and `pull_request: branches: [main], paths:
     ['.github/workflows/fuzz.yml', '_fuzz/**']`, so the lane's own plumbing is proven on
     the PR that adds it and on every later `_fuzz` change.
   - `permissions: contents: read` and nothing else.
   - `concurrency: group: fuzz-${{ github.event_name == 'pull_request' && github.ref ||
     github.run_id }}`, `cancel-in-progress: ${{ github.event_name == 'pull_request' }}`
     — PR runs supersede, scheduled runs never cancel each other.
   - Job `fuzz`: `runs-on: ubuntu-latest`, `timeout-minutes: 45`, and a container block
     whose `image:` and `options:` lines are copied BYTE-IDENTICALLY from
     `docs.yml:31-33`. `_build/workflows_test.tl` asserts one distinct `image:` line and
     one distinct `options:` line across every workflow, that the image is digest-pinned,
     that every non-exempt job is containerised, and that each containerised job both
     `useradd`s a `builder` and runs `runuser -u builder`.
   - Steps, in order: `actions/checkout` at the same pinned sha as `docs.yml:37`;
     "prepare non-root builder", copied verbatim from `docs.yml:39-45`; NO
     `actions/cache` step (a deep lane must never inherit a shallow run's markers);
     a `plan` step writing `seed` and `iters` to `$GITHUB_OUTPUT` — `seed` = the dispatch
     input when non-empty else `date -u +%Y%m%d`, `iters` = the dispatch input when
     non-empty else `2000` when `github.event_name == 'pull_request'` else `50000`; then
     the deep step (`timeout-minutes: 30`) which prints
     `deep-fuzz: seed= iters=`, appends that line and
     `FUZZ_SEED= FUZZ_ITERS= bin/cosmic --make test _fuzz` to
     `$GITHUB_STEP_SUMMARY`, and runs
     `runuser -u builder -- env HOME="$HOME" PATH="$PATH" FUZZ_SEED= FUZZ_ITERS=
     bash -ec 'bin/cosmic --make fetch; bin/cosmic --make test _fuzz'` under `set -eux`
     with no guard; then `actions/upload-artifact` with `if: always()`, `name:
     deep-fuzz-${{ steps.plan.outputs.seed }}`, and paths `o/_fuzz/*.test.out`,
     `o/_fuzz/*.test.err`, `o/_fuzz/*.test.time` (the base the test rule records under —
     `record $(basename $@)`, `embed/cosmic.mk:188-189`).
   - `_fuzz` as a selection path covers every file under it, current and future
     (`_make/select.tl:19-24`), so a new fuzz module joins the lane by existing. Do not
     enumerate module paths in the workflow.
2. **`--- env: FUZZ_SEED FUZZ_ITERS`** added to the five modules that lack it —
   `_fuzz/compress_fuzz_test.tl`, `_fuzz/json_fuzz_test.tl`, `_fuzz/re_fuzz_test.tl`,
   `_fuzz/tar_fuzz_test.tl`, `_fuzz/url_fuzz_test.tl` — as one line inside each file's
   leading `---` doc-comment block, exactly the shape of `_fuzz/sse_fuzz_test.tl:4`. One
   line per file; every file has headroom (facts above). Without this, five of six
   modules replay a cached shallow verdict whenever only `FUZZ_ITERS`/`FUZZ_SEED` moved,
   which is the vacuity #1156 retired for `sse` alone.
3. **`_build/fuzz_test.tl`** (new, ~50 lines) — the ratchet that keeps the lane honest,
   in the style of `_build/workflows_test.tl`. Header `--- reads: _fuzz` plus
   `--- reads: .github/workflows/fuzz.yml` (one path per line — the `reads:` grammar is
   single-token today, see Non-goals):
   - `test_every_fuzz_module_declares_its_env`: every `_fuzz/*_fuzz_test.tl` contains a
     line `--- env: FUZZ_SEED FUZZ_ITERS`; the failure message says why (a module without
     it replays a cached shallow verdict in the deep lane, so its deep PASS is a lie).
     Assert the module list is non-empty, so the loop cannot pass vacuously.
   - `test_the_deep_lane_runs_the_whole_directory`: `.github/workflows/fuzz.yml` exists
     and contains `--make test _fuzz`, so deleting or narrowing the lane fails a test
     rather than silently ending the cadence.
4. **`AGENTS.md`** — two edits, prose only: add `fuzz.yml  daily deep fuzz (--make test
   _fuzz)` to the `.github/workflows/` block (`AGENTS.md:53-56`), and a `- **fuzz.yml**:`
   bullet to the CI section beside the `docs.yml` and `release.yml` bullets
   (`AGENTS.md:493-497`) stating the cadence, the depth, the seed source, and that a red
   lane never blocks a release.
5. Ratchet clause: if the coverage or casts gate complains about the new files, run
   exactly the regen command the failure message prints and commit the result — in scope,
   and never a gate weakened any other way.
