## Evidence

gitboard's cost is git processes, not Lua. Measured 2026-09-04 on the pinned
release (2026-09-04-98dd25d) against the live board, 915 items, 1,864 refs,
warm cache, best of five (`for i in 1 2 3 4 5; do time o/bootstrap/gitboard
show; done` from a cosmic checkout with `GITBOARD_DIR=o/board`; process
counts by `strace -f -e trace=execve`): `--help` 0.007 s; `show` 0.18 s and
7 processes (6 git); `show ID` 0.17 s, 13 (12 git); `next` 0.15 s, 7;
`find` 0.02 s, 2; `sync` 0.65–0.96 s, 11 (network); `show` with the cache
removed 0.58 s (rebuilds the 8.5 MB `o/board.db`); `fsck` 14.6 s, 4,465
(4,464 git). Mutations in a sandbox clone with a local bare origin: `new`
0.25 s, 24 (21 git); `compare` 0.36 s, 25 (22 git); `take` 0.30 s; `done`
0.24 s, 6. Nothing records these numbers over time: a regression in a verb's
latency is noticed by a session that finds it slow, or not at all.

Cosmic already has the harness shape: `_perf/harness.tl` runs `Scenario`
records (`_perf/perf_types.tl`: `name`, `setup`, `fn`, `check`, `teardown`),
calibrates iterations, takes samples, reports median wall ns with a spread,
and `_perf/gate.tl compare BASE CUR SELF` is the noise-aware regression gate;
`_perf/run.tl` discovers `_perf/bench/*_bench.tl` relative to the working
directory (`BENCH_DIR` at run.tl:174, `fs.find(BENCH_DIR, {glob =
"*_bench.tl"})`) and requires each by module name. The process-count
RATCHET is a separate change (`_work/procs_test.tl`, deterministic, in
`--make ci`); this item is the wall-clock half, which is noise-bound and
therefore observed, never gated.

## Change

Wall-clock scenarios for gitboard in cosmic's shape, measured against a
generated fixture, compared release-against-main daily, blocking nothing.

1. Ready when: `bin/cosmic --make test _work/procs_test.tl` passes on
   main (the ratchet's fixture-board builder is what this reuses).
2. `_perf/fixture.tl`: build a board of N synthetic items (default 1,000;
   `GITBOARD_PERF_N` overrides) in a local bare origin plus a clone under a
   temp dir, deterministic ids/titles/specs so two runs measure the same
   board, with edges in the proportions the live board has (measure them
   once with `gitboard fsck`/the index and write the ratios into the
   generator's header). No network anywhere in this tree's perf work.
3. `_perf/bench/verbs_bench.tl`: one Scenario per verb, `fn` spawning the
   built `o/bin/gitboard` through `cosmic.child` with `GITBOARD_DIR` at
   the fixture clone so the binary's own startup is inside the number, the
   way cosmic's `startup_*` scenarios spawn cosmic: `show`, `show ID`,
   `next`, `find`, `fsck`, `sync` (local origin), `cold_show` (the cache
   removed in `setup`), and the mutations `new`, `compare`, `done`, each
   mutation's `setup` cloning a fresh copy so `fn` never measures its own
   residue. `check` asserts the verb's exit code and verdict line
   (`gitboard-<verb>:` prefix).
4. Running: decide, by trying it, whether cosmic's `_perf/run.tl` invoked
   from this tree finds `_perf/bench/verbs_bench.tl` and resolves
   `_perf.harness` from the pinned cosmic's embedded copy (`bin/cosmic
   _perf/run.tl --out o/perf/current.json` from the repo root). If it does,
   that is the runner and nothing is written here; if not, `_perf/run.tl`
   in this tree is a thin CLI over `require("_perf.harness")` reusing
   cosmic's records, not a second harness. Record which in the file header
   with the command that decided it.
5. `.github/workflows/perf.yml`: daily, after release.yml's window: build
   the tree, measure twice (A/A for the noise floor via `_perf/gate.tl
   selfcheck`), measure the latest release's binary on the same fixture,
   run `_perf/gate.tl compare`; a `perf-compare: FAIL` turns the lane red
   and blocks nothing (cosmic's D44 applies). Readings are the run's
   artifacts. The workflow's shape is cosmic's `.github/workflows/perf.yml`.
6. README: one paragraph naming the two halves — the ratchet gates process
   counts, the scenarios observe wall time — and the command to run
   scenarios locally.

## Non-goals

Gating any PR on wall time; `Benchmark_*` micro-benchmarks (gitboard's
Lua is not where the time goes); measuring against the live board or over
the network; fixing any verb — a slow number here becomes its own item
with the reading as evidence.
