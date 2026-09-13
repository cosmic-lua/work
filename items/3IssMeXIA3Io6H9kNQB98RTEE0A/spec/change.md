Wall-clock scenarios for gitboard in cosmic's shape, measured against a
generated fixture, compared release-against-main daily, blocking nothing.

1. No ready-when: nothing here waits on another change.
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
6. README: one paragraph saying what the scenarios measure, that they
   gate nothing, and the command to run them locally.
