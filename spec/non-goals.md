- No line coverage, no `MODE=cov`, no change to `build/config.mk`,
  no touch of `libc/intrin/gcov.S` — the line-level route is
  3Il43qrU0v1rsyrdnssXqBUOjuH.
- No new binding, no change to any test's assertions; a test may be
  ADDED to raise a floor, never weakened.
- No per-line or per-branch counts from the ticks/depth columns; no
  whole-log function counts as a gated quantity.
