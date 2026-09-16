
Measured 2026-09-16 while running the top-10 token-efficiency list.

The board checkout's local `main` was at `8aa4dc4c1`; `origin/main` was at
`7f21457c4`, 50 commits ahead. Four claims were taken with no `--fetch-base`
and none refused:

    gitboard-claim: claim set confirmed        (x4)

Four worktrees were then created from that base, each reporting success:

    build: PASS (222 files, 1 binary)
    gitboard-worktree: AAt2Citw at ... (bootstrap: cosmic (verified runtime,
      build process passed))

The same four worktrees rebuilt on the correct base report
`build: PASS (348 files, 1 binary)` — 126 files of the tree were simply
absent, including whole modules.

A builder spawned into one of them spent 21 tool calls and 71,869 tokens over
115s establishing that `_work/stateclaim.tl` "does not exist anywhere in this
worktree", traced it via `git log --all --diff-filter=A --name-only` to the
unmerged `origin/impl/gitboard-format6` branch, and concluded — carefully,
and wrongly — that the spec had been written against that branch. The file is
on `origin/main`. The worktree was not.

Cost of the single occurrence: 4 claims, 4 worktree builds (each a full
runtime download plus a 222-file build), 4 brief emissions, 4 agent spawns,
~72k tokens in the one agent that reached a report, and 12 orchestrator calls
to diagnose, drop, prune and redo.