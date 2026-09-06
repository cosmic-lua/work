## Evidence

The review brief (work#62) says "CI is read from `gitboard show ID`
(the board's own head-check observation)", but `show` renders no CI
line: `bin/gitboard show 3Iy8ljyJ` (2026-09-06, a doing item with an
open PR) prints `pr:`, `verdict:` and the spec — no check state — and
the PR 1768 reviewer spent 2 calls on `help show`/`help take` to infer
that no red flag meant green. The observation exists: `_work/ciobs.tl`
`current_state` returns green/red/running per (repo, pr) and `take`
refuses on it ("head … has CI running (3 of 5 checks done)").

## Change

`_work/gitshow.tl`: for a doing item with a `pr`, one line after
`pr:` — `ci: <green|red|running> (<done> of <total> checks, head
<sha7>, observed <n>m ago)` from `ciobs.current_state`, or `ci: not
observed` when no row exists. `_work/gitshow_test.tl`: a fixture row
green on the head → the line; no row → `not observed`.

## Non-goals

No live GitHub call in `show`; the line reads the cache `sync` fills.
