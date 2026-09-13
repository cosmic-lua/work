`_work/gitshow.tl`: for a doing item with a `pr`, one line after
`pr:` — `ci: <green|red|running> (<done> of <total> checks, head
<sha7>, observed <n>m ago)` from `ciobs.current_state`, or `ci: not
observed` when no row exists. `_work/gitshow_test.tl`: a fixture row
green on the head → the line; no row → `not observed`.
