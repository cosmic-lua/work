## Change

`bin/cosmic --make ci` on this repository spends ~140 s of wall time
in the coverage stage, which runs every `_work/*_test.tl` instrumented
(`o/coverage-summary.txt`: `wall: 139559ms  slowest:
.coverage/_work/gitverbs_test.tl (10752ms)`); sixteen agent slices
today each ran that gate six to ten times. Profile the suite and cut
it: measure per-file wall time from the coverage summary and the test
runner's `slowest:` lines, then for the ten slowest files find what
they wait on — each `init_state_repo` spawns `git init` plus a fetch
of the pinned runtime, `publish_race_test` and `storeref_test` create
several repositories, `gitverbs_test` runs whole verb pipelines per
case — and remove the wait: share one initialized template repository
per test file and copy it (`cp -r`, not `git init` plus `gitboard
init`), reuse one `cosmic` runtime per process, and split any file
that serialises many independent repositories. Report before/after
wall time in the PR, with the test-result cache cleared
(`rm -rf o/.coverage`) before each timed run — a warm cache replays
stale per-file timings instead of re-executing, and reads as a false
improvement.

## Target (amended — see Evidence below for why)

The original target ("the whole `--make ci` under 60s ... with no
test deleted or weakened") is revised after a builder applied every
named technique everywhere it legitimately applies and measured the
actual ceiling with hard evidence (below): the corrected target is
**the largest wall-time reduction achievable through the named
techniques alone, verified before/after with the cache-clearing
discipline above, with no test deleted or weakened** — not a specific
number. A diff that applies the named techniques exhaustively and
reports honest before/after numbers meets this item's bar even short
of 60s; a diff that stops before exhausting them, or reports numbers
without clearing the coverage cache, does not.

## Evidence (added at amendment time)

A builder measured, with `o/.coverage` cleared before each run:

| `COSMIC_JOBS` | wall time |
|---|---|
| `1` (serial control) | 414s |
| `4` (default = `nproc` in this sandbox and on GitHub's `ubuntu-latest`) | 125s, 127s, 127s (three runs) |
| `8` (2x `nproc`, oversubscribed) | 129s |

1→4 jobs cuts wall time ~3.3x — real parallelism scaling with the 4
physical cores. 4→8 gives **zero** improvement (129s vs. ~126s,
within noise) — the signature of CPU-bound work (process
fork/exec/dynamic-link/interpreter-startup cost, competing for 4
cores), not I/O-bound work that oversubscription would help. This
directly refutes the hypothesis that increasing the coverage stage's
own concurrency past `nproc` could close the gap to 60s: there is no
free concurrency left to extract on this core count.

With the template/copy, runtime-reuse, and file-splitting techniques
already applied everywhere `fixture.init_state_repo`/`init_shared` and
similar heavy per-case git setup appear across `_work/`, the
before/after this builder measured was **172s → ~127s (~26%
reduction)**, `ci: PASS`, same test count, no test deleted or
weakened. Closing the remaining gap to 60s would require roughly
halving total per-test CPU work — e.g. `_work/converge_test.tl`'s 32s
is pure in-memory algorithm simulation with zero git calls, so no
fixture technique touches it — which means touching the verb-pipeline
logic under test itself, not its fixture setup. That is a different,
larger change than "profile the suite and cut fixture overhead," so
it is explicitly a Non-goal here, not a gap in this diff.

## Non-goals

Restructuring or removing test cases to reduce their own CPU work
(only fixture/setup overhead is this item's target). Changing
`.github/workflows/board.yml`'s job count or any other CI
infrastructure — the evidence above shows the default (`nproc`) is
already the workload's sweet spot on this core count, so there is
nothing to tune there. Touching `_work/converge_test.tl` or other
git-free test logic.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
