`gitboard help orchestrate`'s worktree bullet: state outright that a
builder brief's worktree is created by the orchestrator itself (`git
worktree add -b <branch> <path> <default-branch>` — the branch does not
exist yet; `take` only records board state, never a git ref) and its
path passed to the agent in the prompt — and that the Agent tool's own
`isolation: "worktree"` option must never be used for a gitboard-claimed
item, since it creates an unrelated worktree (or, run from a
non-product-repo cwd, refuses outright), not the one `take` named.
