## Problem

The fork's Lua bindings are the part of cosmopolitan cosmic depends on
and modifies most (`tool/net/l*.c`, `tool/lua/lcosmo.c`,
`third_party/lua/cosmo/lunix.c`: ~10,000 lines at origin/master
2026-09-02), and nothing measures how much of that C the test target
exercises. What exists gates the SURFACE, not the code:
`tool/lua/test_definitions_coverage.lua` ratchets that every registered
binding is annotated; `test_definitions_conformance.lua` type-checks a
curated set of pure bindings at runtime; #345/#347 gate the shape
comments. Measured 2026-09-02: of 417 annotated functions and methods
in `tool/net/definitions.lua`, 206 are referenced by name in any
`tool/lua/test_*.lua`; the rest (120 unix methods and predicates, 79
lsqlite3, 12 zip) can regress silently. cosmic's own `.cosmic-coverage`
ratchets Teal line coverage per wrapper file and has no C analogue.
`tool/net/lcov.c` is a Lua line-hit collector, not C coverage; no
`-fprofile-arcs`/gcov appears anywhere in `build/` or `tool/lua/BUILD.mk`.

**2026-09-05 update — the premise above is now partly stale.** The
feasibility slice this outcome named ran and closed
(3Il1RVDaKyr00zNMfdvnoW6jglZ, `## Result`: cosmocc's gcc instruments
correctly but ships no gcov runtime; an in-tree one is buildable), and
three follow-on items built and merged it: an in-tree `.gcda` writer
matching GCC 14.1's `gcov_info` layout
(3Il43qrU0v1rsyrdnssXqBUOjuH, cosmic-lua/cosmopolitan#359), a
read-add-write merge across the suite's ~65 test processes
(3Ilf3Lh50nV3sLMPXBo7Y4J6NcJ, #362), and an `F_SETLKW` lock closing the
race the merge left between concurrent writers
(3Ip8xYTOwHNyZ9ZMWNCqqTpaJfw, #380) — all `completed`. So
`-fprofile-arcs`/gcov DOES appear in `build/config.mk` and
`tool/lua/BUILD.mk` today (`ifeq ($(MODE),cov)`), and `make MODE=cov
o/cov/tool/lua/test` does write a correct, merge-safe `.gcda` beside
every instrumented object. A parallel item
(3Il1RfbQnDkO4vgNmWp2BAVip7R, #354) also shipped a per-file FUNCTION
coverage floor from `--ftrace` in default mode
(`tool/lua/coverage_floor.lua`) as the pragmatic fallback the
feasibility result recommended — that is a real, working ratchet, but
it is function-level, not the line-level one below.

What is still missing, and what this outcome's two open children
close: nothing yet reads that `.gcda` into a per-file LINE count, no
floor file for it exists, no gate gates it, and — until
3IvOr6Gxxn8pZGF53TUjsyrD5ML lands — no CI job ever builds or runs
`MODE=cov` at all, so today's writer has zero CI coverage of its own.

## Outcome

A per-file C line-coverage floor for the binding sources, ratcheted
the way `.cosmic-coverage` is: a `MODE` that instruments those files,
a committed floor file, and a gate in the test target that fails when
a file's covered-line count drops below its floor and rewrites the
floor only on request. The first slice decided feasibility (closed,
see above); the two open children close the rest: CI actually running
`MODE=cov` (3IvOr6Gxxn8pZGF53TUjsyrD5ML), then the line-count
extraction, floor file, and gate (3IvOz0wCf4X7FI70PFVW3uoBvcn).

## Non-goals

- No change to which bindings the tests exercise (raising coverage is
  ordinary follow-on work the ratchet then protects).
- No instrumentation outside `tool/net`, `tool/lua`, and
  `third_party/lua/cosmo` — the fork stays mergeable with upstream.
