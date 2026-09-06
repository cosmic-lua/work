## Evidence

Surfaced 2026-09-06 while building board item `8TDI_yqOV` (lfetch.c
line-coverage flake investigation, PR `cosmic-lua/cosmopolitan#390`),
out of scope for that item (which explicitly excludes a general audit
of test determinism).

`tool/lua/test_fetchstream_edge.lua`'s `test_stream_https` makes a
real network call to `https://httpbin.org/stream/3` — one of (at
least) four independent branches `8TDI_yqOV`'s investigation traced
`lfetch.c`'s line-coverage variance to (gcov per-line JSON diffed
across ~50 `MODE=cov` runs; PR #390 derives the true floor, 579, as
the always-covered base, with this branch's real-vs-skipped execution
contributing part of the 579-592 range).

**This is NOT a new test-correctness question — it was already raised
and settled by `mQ2B_8Pwr` (accepted, PR #296, completed 2026-08-30),
which explicitly considered this exact test:**

> One test (`test_stream_https`) reaches `httpbin.org/stream/3` over
> the real network and already self-skips with a printed note when
> the network is unavailable... carry that guard as-is; it needs no
> policy decision the way the proxy slice's httpbin tests do, since it
> degrades gracefully by construction.

That verdict stands and this item does not re-litigate it: the test's
own self-skip design is correct and settled. What `mQ2B_8Pwr` could
not have weighed is `8TDI_yqOV`'s parent item `3IvOz0wC`'s
line-coverage floor gate (`tool/lua/line_coverage_floor.lua`), which
did not exist until 2026-09-06 — a gate that fails a build based on
exactly how many lines got covered, which is sensitive to whether this
test's network branch fires or skips in a given run. The self-skip
design being correct for test HYGIENE doesn't make its variable
participation free for line-COVERAGE ACCOUNTING, which is this item's
actual, narrower scope.

## Change

Not written — needs `8TDI_yqOV`'s merged PR (`#390`) read first: it
already narrows the exact lines this branch touches
(`tool/net/lfetch.c:447,448,456` per that PR's own summary) and
derives 579 as the always-covered floor precisely BECAUSE it treats
this branch (and the other three flaky ones) as sometimes-absent —
i.e. the floor-accounting side of this may already be as settled as
the test-hygiene side was by `mQ2B_8Pwr`. Refining this item is mostly
a verification pass: confirm `line_coverage_floor.lua`'s current
579 comment (post-#390) already accounts for this branch's
skip/no-skip variance correctly, rather than assuming there is
remaining work. If it does, this item should close as already
resolved by `#390`, not produce a second Change.

## Non-goals

- Not re-opening `mQ2B_8Pwr`'s settled test-hygiene verdict — the
  self-skip design is correct and stays.
- Not re-opening `8TDI_yqOV`'s own scope (the floor value, the other
  three flaky branches it also identified).
