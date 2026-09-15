Does not change what a first claim or a review claim records. Does not touch
`--fetch-base`, whose job (fast-forward a stale local branch) is unrelated.

Does not address the worktree that a rework runs in; `worktree` already refuses
to reuse a branch, and the rework continues on the branch it already has.
