Landing procedure for this item: work in `o/board` (already a
worktree of `board`). Build and test with the board's own
`bin/cosmic --make ci` / `bin/cosmic --make test _work/...` exactly as
any cosmic project is built (per AGENTS.md). When it passes, commit
directly to `board` and push — no PR, no `gitboard verdict`. Close the
item with `gitboard done <id> --reason completed --force --why
'board-tooling change, committed directly to board (no PR to review)'`.
