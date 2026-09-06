## Evidence

Surfaced 2026-09-06 while building board item `8TDI_yqOV` (lfetch.c
line-coverage flake investigation, PR `cosmic-lua/cosmopolitan#390`),
out of scope for that item (which explicitly excludes a general audit
of test determinism).

`tool/lua/test_fetchstream_edge.lua`'s `test_stream_https` makes a
REAL network call to `https://httpbin.org/stream/3` — one of four
independent flaky branches that item's own investigation traced
`lfetch.c`'s line-coverage variance to (gcov per-line JSON diffed
across ~50 `MODE=cov` runs; this branch's participation alone explains
part of the observed 579-592 range). Independent of the coverage
question, an external, live, third-party network dependency inside
what runs as a unit test is a general test-hygiene concern: it is not
`SKIP`-gated the way `test_proxy_env_var` and similar
environment-conditional tests elsewhere in this suite are, it is
timing- and availability-dependent on a third party this project does
not control, and its participation is what makes some `MODE=cov` runs
(including at least some real CI runs) exercise a different code path
than others — non-hermetic by construction.

## Change

Not written — this item's Change needs a decision the discovering
builder's evidence does not settle: mock the endpoint (a local
fixture server, matching how `test_fetch_local.lua`'s other tests in
the same file avoid real network calls), gate it behind a
network-available check with a `SKIP` message (the existing pattern
for `test_http_proxy_env_var`, `_tool/testrun.tl` or wherever this
suite's `SKIP` convention lives), or accept it as a deliberate
integration-style probe and exclude ITS specific lines from
`tool/lua/line_coverage_floor.lua`'s accounting for `lfetch.c` rather
than changing the test. Refining this item should read `8TDI_yqOV`'s
merged PR (`#390`) first — it already narrows the exact lines this
branch touches (`tool/lua/lcosmo.c`... no, `tool/net/lfetch.c:447,448,456`
per that PR's own summary) and the gcov-diffing technique used to find
them, rather than re-deriving either from scratch.

## Non-goals

Not re-opening `8TDI_yqOV`'s own scope (the floor value, the other
three flaky branches it also identified) — this item is specifically
about `test_stream_https`'s live network dependency as a test-hygiene
question independent of coverage accounting.
