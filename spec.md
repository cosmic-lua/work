## Evidence

`gitboard help orchestrate`'s worktree convention says a builder agent
gets one fresh worktree, on the branch `take` names, prepared by the
orchestrator and passed to the agent by path. Separately, the Agent
tool (the harness's own subagent launcher) offers an `isolation:
"worktree"` option that creates ANOTHER worktree of its own choosing,
unrelated to the one `take`/`gitboard` already prepared for that item.

«wDH9_Z8Zx» (friction: 2026-09-06 work9, `/work 9 --routine`) hit this
on its first builder spawn: passed `isolation: "worktree"` to the Agent
tool for a claim already bound to a gitboard-prepared worktree at
`/home/user/wt/GLwD_dfBT`. Caught immediately — the tool result gave
no confirmation the agent's cwd matched the intended path — and fixed
by stopping the agent (`TaskStop`) before it did any work and
re-spawning without `isolation`, cd'ing into the gitboard-prepared path
explicitly in the prompt instead. Cost: one wasted launch+stop cycle,
~3 tool calls; no stray worktree was left behind
(`git worktree list` confirmed). The friction log's own diagnosis:
nothing in `help orchestrate` or the builder brief warns that the two
mechanisms — the Agent tool's `isolation: worktree` and gitboard's own
`take`-named worktree — must not both be used for the same claim;
read in isolation, the Agent tool's own option looks like the correct
way to hand a subagent its own checkout.

**Second occurrence (2026-09-06, «friction: 2026-09-06 work5-routine»,
`/work 5 --routine`)**: an independent orchestrator session hit the
identical failure mode on its very first Agent call of the pass, before
any gitboard-prepared worktree existed — `isolation: "worktree"`
against a cwd (`/home/user`, not a git repository) that isn't the
target product repo at all, which the harness refused outright
(`Cannot create agent worktree: not in a git repository and no
WorktreeCreate hooks are configured`). No wasted agent launch this time
(the harness's own refusal caught it before spawning), but it is the
predicted second repro this item's own Non-goals anticipated ("reproduces
on the very first builder spawn of any pass that reaches for the Agent
tool's own isolation option, not on some rarer condition") — now
confirmed across two independent sessions, one of which didn't even get
as far as a live worktree conflict before tripping over the same
mechanism confusion.

## Change

`gitboard help orchestrate`'s worktree bullet: state outright that a
builder brief's worktree is created by the orchestrator itself (`git
worktree add -b <branch> <path> <default-branch>` — the branch does not
exist yet; `take` only records board state, never a git ref) and its
path passed to the agent in the prompt — and that the Agent tool's own
`isolation: "worktree"` option must never be used for a gitboard-claimed
item, since it creates an unrelated worktree (or, run from a
non-product-repo cwd, refuses outright), not the one `take` named.

## Non-goals

Not a harness change — the Agent tool's `isolation: worktree` option is
not being asked to detect or refuse this case; the fix is stated
doctrine at the point orchestrators read it. Two independent occurrences
now on record (this item's own prediction of a structural, not rare,
conflict is confirmed); the doc fix is unchanged in shape from the
original Change, just no longer waiting on a second data point to
justify prioritizing it.
