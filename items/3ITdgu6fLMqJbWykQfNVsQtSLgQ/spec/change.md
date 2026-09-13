`_perf/skew_test.tl` — one test that type-checks every non-test
`_perf/**/*.tl` under the pinned bootstrap binary
(`o/bootstrap/cosmic`), in ONE `--check types` invocation (the check
verb fans out over every file named and exits with the worst result).

Why the bootstrap is the right bar: `bin/cosmic.pin` only ever trails
published releases, so the bootstrap is at least as old as the
previous release the compare step downloads — bootstrap-clean implies
prev-release-clean. Verified mechanics (2026-08-27, by hand):
- an old release binary's `--check types` resolves `cosmic.*` from
  its EMBEDDED declarations even from the repo root (a typed two-arg
  `literal.format` probe fails under the 08-23 release, passes under
  the tree binary), and resolves `_perf.*` from the tree at cwd —
  exactly the compare step's bare-load resolution.
- the pre-#1420 literal_bench (14ff1d1d) FAILS the sweep at its line
  140; the landed capability-probe version PASSES. Both directions
  reproduce in-tree.

Shape:
- collect via `fs.find("_perf", {glob = "*.tl"})`, drop `*_test.tl`,
  sort; assert non-empty (a sweep that found nothing is a gate that
  lies).
- assert `o/bootstrap/cosmic` exists, message naming the remedy (run
  bin/cosmic once); never silent-skip.
- `child.run` with `env.list({set = {COSMIC_COVERAGE = "0"}})` so the
  bootstrap child never dumps .cov files for its embedded sources
  into the per-test coverage directory.
- failure message names the class and the remedy — reach a new cosmic
  API from `_perf/**` through a tolerant map view + capability probe
  (pattern: _perf/bench/literal_bench.tl) — quoting the child stderr.
