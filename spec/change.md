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
