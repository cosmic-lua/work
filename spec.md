## Evidence

`bin/gitboard` finds the board as a sibling clone `../work` of the checkout it runs in (cosmic#1764, #1768). Run from a worktree (`/home/user/wt/<id8>`, where `gitboard worktree` puts every builder), the sibling is `/home/user/wt/work`, which does not exist, so it falls back to `<worktree>/o/board` and fails: `take ID --open` from `/home/user/wt/3IyGWAnf` → `not a git repository: /home/user/wt/3IyGWAnf/o/board` (2026-09-06, twice in one orchestrator pass, one wasted call each). `git -C <worktree> rev-parse --git-common-dir` prints the main checkout's `.git`, whose parent's sibling `../work` is the board.

## Change

`bin/gitboard`'s sibling probe tries, in order: `../work` beside the current checkout; then `../work` beside the main worktree (`$(git rev-parse --git-common-dir)`'s parent directory, when it differs); then the existing `o/board` fallback. `_cli/gitboard_root_test.tl`: a fixture where the script runs from a linked worktree whose main checkout has a `../work` sibling resolves to that sibling; the existing cases hold.

## Non-goals

No change to the pin or to what the board is once found; no new flag.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.

## Ready when

`bin/gitboard show X` run from a `git worktree` of the cosmic checkout resolves the board and prints the item, and the test fixture for the linked-worktree case passes.
