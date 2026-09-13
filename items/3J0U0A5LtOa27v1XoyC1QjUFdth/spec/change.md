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
