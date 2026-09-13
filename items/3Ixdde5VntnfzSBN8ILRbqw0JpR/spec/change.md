Every WRITE verb (`new`, `attach`, `rank`, `set`, `spec`, `take`,
`drop`, `verdict`, `done`, `init`) refuses, before any commit, when
the store checkout is a linked worktree: verdict line `REFUSED: <dir>
is a linked worktree of <common-dir> — a builder's worktree is never
a board; run board verbs from the orchestrator's checkout`. Read verbs
(`show`, `next`, `brief`, `find`, `fsck`, `sync`) are unaffected. The
check lives where the store opens for writing (`_work/store.tl` or
`_work/storeinit.tl`, whichever `storewrite.tl` reaches first —
measure), implemented with the two `git rev-parse` calls above.
`_work/storeinit_test.tl` (or `store_test.tl`): a fixture repo plus a
`git worktree add` of it; `new` in the worktree refuses with that
line, `show` in it still works.

`gitboard help orchestrate`, the worktree bullet: one sentence — a
builder's worktree of the board repo is linked to the live clone; the
tool refuses board writes there, so a builder never smoke-tests a
verb outside the test suite's fixtures.
