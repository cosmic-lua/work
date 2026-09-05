# friction: 2026-09-05 work9-routine (/work 9 --routine)

## orchestrator

- goal: reconcile the previous wave — `show` reported `doing 3/10`: two
  `building` claims with no `pr` (5x5P_O61f, baNR_tA4O) and one `review`
  claim with no verdict (GkFk_U7L5), all three under sessions suffixed
  `-32638265`, a prior orchestrator this session has no memory of.
  actually happened: checked `git ls-remote` for the two build branches —
  neither existed on `cosmic-lua/work` — and force-dropped both
  (`gitboard drop ID --force --why ...`, 2 calls) and force-reclaimed the
  review (`gitboard take GkFk_U7L5 --session review-GkFk_U7L5-f3a5b327
  --force --why ...`, 1 call) on the theory that `-32638265` was dead.
  It was not: minutes later `-32638265` claimed a freshly-unblocked item
  (`VkzD_q8u2`, `take` at 02:16:33) and, before this session's freshly
  spawned reviewer could finish, itself recorded `verdict ... accept` on
  the review this session had just taken over and merged PR #22
  (`gitboard show` history: `review claimed by review-GkFk_U7L5-32638265`
  at 02:02:00, force-reclaimed by this session at 02:14:25, then
  `verdict ... accept` by `-32638265` at 02:15:08, `done` at 02:16:28 —
  all recorded under the session this session had just judged dead). The
  spawned reviewer's own `gitboard verdict` call was refused: `REFUSED:
  3It7RFOg already carries an accept — land it` (see its own entry below)
  — a fully wasted review (325s wall, 34 tool calls) whose only surviving
  output is a PR comment on an already-merged PR.
- contributed: nothing in `take`'s refusal, `show`'s claim line, or
  `gitboard help orchestrate`/`help review` distinguishes a claim that is
  merely quiet (its holder mid-build, between board writes) from one
  whose holder is actually gone. The two dead-looking builds (no branch
  pushed at all) turned out to be genuinely abandoned, but the review
  (already had a PR, already had a reviewer claim, just hadn't recorded
  a verdict yet) was not — and the same absence of a liveness signal
  made both cases look identical from `show`'s output alone.
- improvement: a `take --force` over another session's claim could check
  for actual recent activity under that session's name before allowing a
  takeover — e.g. a commit/PR-comment timestamp on the claim's own branch
  or PR newer than some threshold — refusing the force (or requiring a
  second, louder confirmation) when the claimed-dead session has moved
  more recently than the reclaiming session's own read of the board. This
  is a real gate candidate but needs design (what counts as "recent",
  where the check lives) — filed to `candidates` below, not bar-passing
  as stated.

- goal: file a new item, `x1RK_21oE`, for a real defect a spawned review
  found in the (already merged) PR #22.
  actually happened: `gitboard new ... --repo cosmic-lua/work` was
  refused: `claim/reviewer/pr/verdict/repo/base belong to worked items,
  not roots` (1 call) — `help new`'s own printed `--repo` option text
  carries no such caveat. Retried without `--repo`, filed as a root, then
  `attach`ed it under GkFk_U7L5's own parent to pick up a repo/priority
  position (2 more calls; ~10s total, cheap).
- contributed: `gitboard help new`'s options list documents `--repo` with
  no note that it is refused on an unparented item.
- improvement: a one-line addition to `help new`'s `--repo` description
  ("refused on a root — attach first, or the parent supplies it") would
  have saved the failed call. Doc-only, cheap, but this session has no
  checked-out gitboard source to cite a file:line for — candidate only.

- goal: get the new item (`x1RK_21oE`) past the spec bar.
  actually happened: `show` reported `bar: spec reaches cosmic-lua/work
  with no declared read access — name it under "## Access"` — a bar rule
  `gitboard help bar`'s printed doctrine text never mentions (it documents
  `## Change`, `## Non-goals`, `## Acceptance`, and "Ready when:" prose,
  but no `## Access` section at all). Resolved by grepping other items'
  specs for the convention (`git grep -l "## Access" ...`, found 3 hits,
  read one) rather than being told the shape — 3 calls total to close a
  bar that had no doctrine text to consult.
- contributed: `help bar`'s topic text is stale relative to what the tool
  actually enforces.
- improvement: add the `## Access` section's shape and trigger condition
  to `gitboard help bar`'s printed text — a doc gate that would have
  turned 3 exploratory calls into 1 direct one. Candidate only: filing it
  as a board item needs a file:line in gitboard's own source (the help
  text's source location), which this session did not check out to find
  without widening scope beyond the routine pass.

## review GkFk_U7L5 (Sonnet 5) — verdict superseded, 325s wall, 34 tool calls

- goal: record a fresh-context review verdict on PR #22 per the brief's
  exact `gitboard verdict` command.
- actually happened: refused outright — `gitboard-verdict: REFUSED:
  3It7RFOg already carries an accept — land it` (1 error). Full run: 34
  tool calls (Bash=27, ToolSearch=1, mcp__github__pull_request_read=5,
  mcp__github__add_issue_comment=1), tokens in=66 out=388
  cache_read=2,392,534 cache_create=99,859, 2 repeated `cd` commands, no
  file edits. The agent independently found and posted (as a PR comment,
  since it could no longer gate anything) a real defect: the PR's two new
  ambiguity-refusal paths render different message shapes (ids vs.
  tails) — filed as its own item, «x1RK_21oE», above.
- contributed: a second orchestrator session held and resolved the same
  review claim concurrently (see orchestrator's first entry above) —
  this agent did real, correct work (fresh checkout, green `--make ci`,
  a genuine mutation test, a real finding) that the board had no room
  left to record.
- improvement: same as the orchestrator's liveness-check candidate above
  — this agent's entire cost is a direct consequence of that gap, not of
  anything in its own brief or execution.

## build T6Gj_9ge9 — still running at pass end

not yet reported: this pass claimed and spawned it but ended (per
`orchestrate`'s "never wait inside a pass") before it finished. Its PR
and friction land on the board's next reconciliation.

## build 6ImQ_qAgC — still running at pass end

not yet reported, same as T6Gj_9ge9 above.

## build qgFj_DaXr — still running at pass end

not yet reported, same as T6Gj_9ge9 above.

## build x1RK_21oE — still running at pass end

not yet reported, same as T6Gj_9ge9 above.

## candidates

- liveness check before `take --force` over another session's claim
  (recent commit/PR/comment activity under the claimed-dead session's
  name, refused or double-confirmed if newer than the reclaiming read) —
  stays here for triage: needs design, not yet a literal Change.
- `gitboard help new`'s `--repo` option text should note it is refused on
  a root item — stays here for triage: no file:line in hand.
- `gitboard help bar` should document the `## Access` section (shape,
  trigger) it already enforces — stays here for triage: no file:line in
  hand.
