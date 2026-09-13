Not proposing that agents and the orchestrator never share a worktree, or
that the orchestrator stop taking over stalled builds directly — that
recovery path is working and fast. Not about the underlying cause of the
agent's own stall (losing track of a backgrounded long-running command),
which is a separate, already-observed pattern with its own mitigation
(never end a turn with a long command still running in the background).

Not the `build` or `orchestrate` doctrine topics in `_work/doctrine.tl`:
the item is about the brief a builder is handed, and a builder that read
the brief has no reason to run `gitboard help build`. Adding the same
warning there is a separate item if it is wanted at all — leave
`_work/doctrine.tl` untouched.

Not a mechanism that detects or prevents the foreign edit (a lock, a
lease check, a `git status` guard in `worktree`, a warning printed at
build time). This item is the one paragraph of brief text and its test,
nothing else.

Not the review or research briefs: neither runs in a builder's worktree,
and `_work/brieftext_review.tl` is out of scope.
