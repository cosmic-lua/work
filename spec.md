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

## build rhKJ_HSQd (general-purpose) — PR #391 opened, wall=1248s, 105 tool calls

- **Goal** (agent's own words): key `kErrnoNames[]`/`kSignalNames[]` by
  the name format the spec's `## Change` row template showed.
  **Actually happened**: the spec self-contradicted — Evidence stated
  "must key by full name (`"ENOENT"`, `"SIGTERM"`), not the bare
  suffix," while the Change section's own row template said "drop the
  leading `E` from the string." Cost ~15 min of pure reading/reasoning
  (no tool calls) before resolving in favor of full names (the only
  reading consistent with `DEFAULT_SIGNALS`/`code_of("ENOENT")`'s
  existing call sites) — correct in the end, but the agent had to
  re-derive which half of its own spec was right. **Contributed**: my
  spec fix earlier this pass (correcting the item's `LoadMagnums`
  premise) touched the surrounding Evidence text but missed that the
  pre-existing Change template still said the opposite thing —
  introduced by an earlier respec, not this pass's edit, but not caught
  before handing the brief off either. **Improvement**: respec'd this
  pass (see board action below) to fix the row template to match the
  full-name keying the Evidence already required and the built PR
  already implements — cheap, done.
- **Goal**: confirm the spec's coverage-scan claim ("check whether the
  existing coverage scan discovers these fields automatically") against
  the actual gate. **Actually happened**: the named file
  (`test_definitions_coverage.lua`) needed a real extension (as the spec
  anticipated), but a SECOND, unnamed file in the same gate
  (`test_definitions_conformance.lua`) had its own independent runtime
  probe that also broke, discovered only by running the full
  `make o//tool/lua/test` gate rather than reading the two files the
  spec named — ~20 min, ~6 tool calls (build, grep the failure, read,
  fix, re-verify). **Contributed**: the spec's own checklist named one
  file's assumption to verify but not the second file in the same gate
  that carried a parallel one; nothing wrong with the fix once found.
  **Improvement**: none filed this pass — a single occurrence, and the
  gate itself (which the spec already told the builder to run before
  pushing) caught it before it reached a PR; not yet a repeated pattern
  worth a doc change.
- Transcript-level (from `_tool/friction.tl`): 3 tool errors, all
  low-cost — 2 `Read` calls whose `offset` argument was cut off
  mid-JSON by an apparent output truncation (`{"file_path": ...,
  "offset"` with nothing after), immediately retried successfully; 1
  `Bash` call chaining `sleep 30; tail ...` blocked by the harness's own
  anti-polling guard, immediately replaced with a direct (non-blocked)
  command. Neither recurred after the first hit, so no countermeasure
  filed.

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
