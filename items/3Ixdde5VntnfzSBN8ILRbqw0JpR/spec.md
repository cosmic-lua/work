## Evidence

2026-09-06 (work4): a builder for a cosmic-lua/work item ran a manual
smoke test of `_work/gitboard.tl` (`init`, then `new`, `--dir .`) inside
its worktree `/home/user/wt/3IxaZgMq`. That directory is a LINKED
worktree of the orchestrator's live board clone (`git worktree add`
from `/home/user/work`), so it shares refs and a push-capable `origin`:
the `new` committed and pushed a real branch
`items/3Ixbvf4qLvBjqanRPYwIzMOjL2q` ("new 3Ixbvf4q an outcome") to
cosmic-lua/work. The orchestrator deleted it by hand
(`git push origin --delete …`, then `sync`; `fsck` clean). `gitboard`
has no notion of "this checkout is not a board": `_work/storeinit.tl`
opens whatever `--dir` names. A linked worktree is detectable in one
call: `git rev-parse --git-common-dir` differs from `git rev-parse
--git-dir` (in a primary checkout both print `.git`).

`wc -l _work/storeinit.tl` → measure at refine time; `_work/store.tl`
holds the open path.

## Change

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

## Non-goals

No pre-push hook (git-level, per-checkout, easy to forget). No change
to how the orchestrator creates worktrees.
