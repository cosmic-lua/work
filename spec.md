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

**A builder attempt (2026-09-06, `build-XvG7_47u0-d5f3aa35`) stopped
before writing code: `#390` was still open/unmerged at pull time**
(`state: open`, `merged: false`, head `2e320a3` on base `b9246f8d`,
verified directly via the GitHub API), so `line_coverage_floor.lua` at
`origin/master` still carried the pre-`#390` state (585, the old
generic comment) — there was no `579` comment yet to verify. The
builder correctly declined to guess at `#390`'s outcome or duplicate
its uncommitted work. This item was pullable before its actual
precondition (`#390` merged) held; the fix is to state that
precondition explicitly (below) so a future pull checks it first
instead of discovering it mid-build.

## Change

Ready when: `cosmic-lua/cosmopolitan#390` is merged — verify with
`gh pr view 390 --json state,mergedAt` (or the equivalent
`pull_request_read` call) showing `"state": "MERGED"`, or that its
merge commit is an ancestor of `origin/master`. Until then this item
is not resolvable; a puller that reaches it before then drops the
claim bare (item is fine as written).

Once ready, this is mostly a verification pass, not a new fix: read
`#390`'s merged diff and `tool/lua/line_coverage_floor.lua`'s resulting
comment for `tool/net/lfetch.c`. `#390`'s comment already narrows the
exact lines this branch touches (`tool/net/lfetch.c:447,448,456` per
that PR's summary) and derives 579 as the always-covered floor
precisely BECAUSE it treats this branch (and the other three flaky
ones) as sometimes-absent. Confirm the merged comment explicitly
accounts for `test_stream_https`'s skip/no-skip variance (it names the
branch as `FetchStreamRead`'s TLS body-read path, "reached only when
the streaming test's fetch of a real external HTTPS endpoint
succeeds"). If it does — expected, based on the pre-merge diff read
during this item's own refinement — `done` this item as already
resolved by `#390`, with that confirmation as the record; do not
produce a second Change to `line_coverage_floor.lua`. If the merged
comment does NOT name this branch, that is a real gap: STOP and report
what it says instead, since the Non-goals below still hold.

## Non-goals

- Not re-opening `mQ2B_8Pwr`'s settled test-hygiene verdict — the
  self-skip design is correct and stays.
- Not re-opening `8TDI_yqOV`'s own scope (the floor value, the other
  three flaky branches it also identified).
