## Evidence

Three of four PR reviews this session (`OiQb_ry43`/PR#1790,
`wAe5_evHa`/PR#1791, `9R8e_zA8Q`/PR#78 round 2, `vGr9_mgmX`/PR#79) found
the review checkout their `brief review ID` named
(`/home/user/wt/review-<branch>`) did not exist — only the builder's
own worktree did. Each reviewer built its own fresh checkout by hand:
`git fetch origin refs/pull/N/head:pr-N && git worktree add ...`, 2-3
extra tool calls apiece. The brief's own fallback text already
anticipates this ("if your brief's named review checkout path doesn't
exist, construct your own fresh one... rather than reusing the
builder's worktree"), so no review stalled or misread stale code — but
every review paid the same small tax for a step the orchestrator could
do once, the same way `gitboard worktree ID` already provisions the
BUILDER's checkout in one command right after `take ID`.

Distinct from `qWfP_VKKJ` (a builder/reviewer reading the
ORCHESTRATOR's own stale product checkout instead of its assigned
worktree) and `CVYc_iYdJ` (a reviewer re-cloning the BOARD repo instead
of reading the product checkout's cached `o/board`) — this is about the
PRODUCT PR's own review checkout never being provisioned at all,
builder or board.

## Change

A `gitboard worktree` mode for review — either a new flag (e.g.
`worktree ID --review`) or a natural extension of the review-claim
flow — that fetches the PR's current head into a fresh worktree at the
path `brief review ID` already names, the same one-command shape
`worktree ID` gives builders. Run right after claiming a review, before
`brief review ID`, so the brief's named path is live by the time a
reviewer reads it. `brief review ID`'s own text can then drop the
now-unnecessary fallback instruction once the path is reliably
pre-provisioned — or keep it as a safety net, since a reviewer
constructing its own checkout by hand is a correct, if costlier, path
either way.

## Non-goals

Not changing the BUILDER worktree flow, which already works. Not
folding in `qWfP_VKKJ`'s or `CVYc_iYdJ`'s fixes — those are about what
tree an agent reads FROM, not about provisioning the review tree in
the first place.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
