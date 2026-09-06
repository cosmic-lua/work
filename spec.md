## Evidence

`bin/gitboard`'s sibling probe (PR 1764) matches the sibling's origin
with `case … in */cosmic-lua/work | */cosmic-lua/work.git)` —
`grep -n 'cosmic-lua/work' bin/gitboard` places it. An SSH remote is
`git@github.com:cosmic-lua/work.git`: a colon, not a slash, precedes
the org, so the pattern misses it and the tool silently falls back to
`o/board` for a checkout cloned over SSH. `_cli/gitboard_root_test.tl`
exercises HTTPS origins only (`grep -n 'https://' _cli/gitboard_root_test.tl`).

## Change

`bin/gitboard`: the two `case` patterns become `*cosmic-lua/work |
*cosmic-lua/work.git` (drop the leading `/`), which matches both
transports and still refuses `someone-else/work`.
`_cli/gitboard_root_test.tl`: one more case,
`test_prefers_an_ssh_sibling_work_clone`, with origin
`git@github.com:cosmic-lua/work.git` → the sibling path.

## Non-goals

No other origin shapes; no change to the fallback.

## Access

cosmic-lua/work, read only and only in name: the origin URL strings
are fixture values set on throwaway local repos, matched by
`bin/gitboard`'s suffix check and never fetched.
