## Evidence

Surfaced 2026-09-06 while building board item `3IvOz0wC` (handle
«W3uo_Bvcn», "gcov: extract per-file line coverage from MODE=cov and
gate the test target on a committed floor"), out of scope for that
item (which explicitly excludes changing what the tests exercise).

`tool/net/lfetch.c`'s measured line coverage is flaky across otherwise
identical SERIAL (no `-j` at any level) runs of `make MODE=cov
o/cov/tool/lua/test`: observed covered-line counts of 586, 590 (the
majority), and 592 across roughly 26 runs — i.e. about 1-in-10 runs
land below whatever floor gets committed for this file, with no code
change at all. Every one of the other 12 instrumented binding sources
(`third_party/lua/cosmo/lunix.c`, `tool/lua/lcosmo.c`,
`tool/net/largon2.c`, `tool/net/lcov.c`, `tool/net/lfuncs.c` (as
`lfuncs3.o`), `tool/net/lgetopt.c`, `tool/net/ljson.c`,
`tool/net/llua.c`, `tool/net/lpath.c`, `tool/net/lre.c`,
`tool/net/lsqlite3.c`, `tool/net/lzip.c`) was perfectly stable across
all runs — only `lfetch.c` varies.

Suspected cause (not yet confirmed): timing-sensitive control flow in
the real-localhost proxy/timeout tests exercising `cosmo.Fetch`/
`cosmo.FetchStream` — `tool/lua/test_fetch_proxy.lua` and
`tool/lua/test_fetchstream_edge.lua` are the two test files most
likely to hit a timeout/retry/error branch non-deterministically
depending on scheduling.

`3IvOz0wC`'s own line-coverage floor (`tool/lua/line_coverage_floor.lua`)
was committed at 590 (a clean single baseline run) per that item's
literal instructions and precedent (matching how the function-coverage
floor, `tool/lua/coverage_floor.lua`, was originally seeded) — this is
NOT a bug in that item; it is a real, load-bearing risk in the new gate
`3IvOz0wC` adds: `o/cov/tool/lua/test_line_coverage.ok` will
occasionally fail a PR through no fault of that PR's own diff, the
"guard that can't be shown to reliably pass on unrelated changes"
mirror image of the flaky-guard problem this repo's review doctrine
already treats seriously (see also board item `GLwD_dfBT`'s handling
of `test_gcda_merge.lua`'s flaky MISS rate — the same class of
problem, opposite direction: there a real regression could slip
through; here, a correct, unrelated change can be flagged wrongly).

## Change

Investigate why `tool/net/lfetch.c`'s line coverage specifically
varies run-to-run under `MODE=cov`, and stabilize it. Likely paths (not
prescribed — the build should measure and pick, per this repo's own
measurement-first doctrine):

- Identify the specific non-deterministic branch(es) in
  `test_fetch_proxy.lua`/`test_fetchstream_edge.lua` (or elsewhere)
  that sometimes execute and sometimes don't, and either make the test
  deterministic (fixed timing, no real-network race) or accept the
  branch as intentionally environment-dependent and exclude it from
  the line-coverage floor's accounting for this file specifically.
- Alternatively, if a few lines of inherent variance are accepted as
  unavoidable, lower `tool/lua/line_coverage_floor.lua`'s
  `lfetch.c` entry to a value safely below the observed low end (586
  or lower) with a comment explaining why this one file's floor has
  headroom the others don't — a documented tolerance, not a silent
  guess.

## Non-goals

- Not re-opening `3IvOz0wC`'s own scope (which files are instrumented,
  the collector's shape, the BUILD.mk wiring) — that item stands as
  built; this is a follow-on stabilization of one file's measurement.
- Not a general audit of test determinism across the suite — scoped to
  `lfetch.c`'s line coverage specifically, the one file this
  investigation found varying.
