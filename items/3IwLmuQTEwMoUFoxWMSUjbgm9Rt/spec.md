# friction: 2026-09-06 work5-routine (/work 5 --routine)

## orchestrator

- **Goal**: merge `8TDI_yqOV`'s accepted PR (`cosmic-lua/cosmopolitan#390`)
  per `next`'s "finish" instruction. **Actually happened**: a direct
  `merge_pull_request` call failed immediately — `PUT .../pulls/390/merge:
  405 Repository rule violations found / Changes must be made through the
  merge queue` — one wasted API call. Switched to `enable_pr_auto_merge`
  per doctrine, which succeeded, but by the end of the pass (~50+ min
  later, CI green the whole time, `mergeable_state: clean`) the PR was
  still open/unmerged with no review recorded on the GitHub side (`get_reviews`
  returned `[]`) — only the gitboard-side review. **Contributed**:
  `gitboard help review` already states the correct method ("a PR against
  the product repo lands by enabling auto-merge") — the failed direct-merge
  attempt was my own habit, not a doctrine gap. The stall past auto-merge
  is unexplained from here: no branch-protection/ruleset inspection tool
  is available among the GitHub MCP tools this session has, so I could not
  confirm whether the ruleset also requires a native GitHub approving
  review (which gitboard's own review process does not produce) or is
  simply a slow queue. **Improvement**: give the orchestrator a way to read
  the repo's merge-queue/branch-protection rules (or have `enable_pr_auto_merge`'s
  result say whether the PR actually entered the queue) so a real
  configuration gap (e.g. a required native review gitboard's process never
  supplies) is distinguishable from ordinary queue latency. Filed as a
  candidate below rather than acted on — outside what this session's tools
  can diagnose.

- **Goal**: create the builder's worktree on the branch `take` names
  (`orchestrate`: "on the branch `take` names"). **Actually happened**:
  `git worktree add /tmp/wt/XvG7_47u0 3IwFbwiT` failed —
  `fatal: invalid reference: 3IwFbwiT` — because `take` only records board
  state; it does not create the branch. One extra command
  (`git worktree add -b 3IwFbwiT ... origin/master`) fixed it, repeated
  identically for the second worktree. **Contributed**: `help orchestrate`'s
  wording ("on the branch `take` names") reads naturally as "the branch
  already exists" to a first-time orchestrator; it doesn't. **Improvement**:
  one sentence in `help orchestrate` or `help take`: create the branch
  fresh with `git worktree add -b <branch> <path> origin/master` (or the
  repo's default branch) — `take` never creates it. Cheap, filed below.

- **Goal**: launch a builder subagent with the brief `brief builder ID`
  printed. **Actually happened**: passed `$(cat <path>)` as the Agent
  tool's `prompt` string, which is a literal value (no shell involved) —
  the agent launched with the literal, unexpanded text instead of the
  brief. Caught immediately from the tool result's echoed prompt-shape
  concern, stopped the agent (`TaskStop`) before it did anything (worktree
  verified clean after), and relaunched with the brief's actual content
  pasted inline. Cost: one wasted agent launch + stop (no tokens billed
  to the killed agent — it produced no transcript entries). **Contributed**:
  my own error, not a tool or doctrine gap — `brief`'s own instruction
  ("paste the body verbatim") already says to paste content, not to
  reference a file path. **Improvement**: none for the tree; personal
  discipline (read the brief file, paste its actual text) is enough.

## build XvG7_47u0 (general-purpose) — bounced, respec'd, wall=82s, 7 tool calls

- **Goal** (agent's own words): verify the spec's premise before touching
  any file. **Actually happened**: had to reach for
  `mcp__github__pull_request_read` to discover `#390` (a hard, named
  dependency the spec stated as flat fact — "needs `8TDI_yqOV`'s merged PR
  (#390) read first") was still open, not merged — 82s wall, 7 tool calls
  (`Bash`×4, `ToolSearch`×1, `pull_request_read`×2), zero edits. Correctly
  stopped rather than guessing or duplicating `#390`'s uncommitted work.
  **Contributed**: the spec named a specific PR as a hard dependency in
  prose but never as a `## Change`-level "Ready when" precondition (the
  pattern `help bar` itself documents for exactly this case) — refined
  before `#390` finished merging, and nothing re-checked that at pull
  time. **Improvement**: respec'd with an explicit "Ready when: `#390` is
  merged" line (done this pass, see board action below) — a gate a future
  puller checks in one command instead of discovering mid-build. This is
  the `help bar` mechanism working as designed once applied; the gap was
  that refinement hadn't applied it originally.

## build rhKJ_HSQd (general-purpose) — still running at pass close

- Not yet reported when this pass closed; per `orchestrate` doctrine
  ("never wait inside a pass ... not for a wave agent") the pass ends
  without it. No observation to record yet — its friction, if any, is
  recorded when it reports, in whichever pass reconciles this wave.

## candidates

- `help orchestrate`/`help take`: state explicitly that the worktree
  branch does not exist until the orchestrator creates it
  (`git worktree add -b <branch> <path> <default-branch>`), not merely
  "on the branch `take` names" — stays here for triage: it's a fix to
  gitboard's own help text in `cosmic-lua/work`, outside this pass's
  claimed items (`cosmic-lua/cosmopolitan`/`cosmic`), and small enough
  that filing a full board item felt heavier than the fix; flagging here
  for whoever next touches that help text.
- Give `enable_pr_auto_merge`'s result (or a dedicated verb) a way to say
  whether a PR actually entered a merge queue vs. is blocked by an
  unmet requirement (e.g. a native GitHub review gitboard's own review
  process doesn't supply) — stays here for triage: needs someone with
  branch-ruleset visibility to confirm what `cosmic-lua/cosmopolitan`
  actually requires before this is actionable as a spec.
