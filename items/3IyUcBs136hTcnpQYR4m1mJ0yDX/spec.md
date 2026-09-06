## Evidence

`gitboard show CM0F_Tk4k` run from /home/user/cosmic (the product checkout `bin/gitboard` lives in) prints `absent: _work/brief.tl does not exist in the tree`, `absent: _work/brieftext_review.tl …`, `absent: _work/brief_rework_test.tl …` for an item whose `repo:` line is `cosmic-lua/work` — all three exist in the work checkout (`wc -l /home/user/work/_work/brief.tl` → 441). The `absent:` probe resolves the spec's cited paths against the checkout the command runs in, not against the item's repo, so every work-repo item read from the cosmic checkout reports its own files as missing, and a reviewer reading `show` (the brief tells them to) sees three false gaps (the PR 1769 reviewer reported them as "expected pre-merge, not a defect" — a guess).

## Change

`show`'s path probe (and `take`'s bar check where it shares it) resolves a cited path against the checkout of the item's `repo:`: the current checkout when its origin matches, else the sibling clone `bin/gitboard` already locates for the board (`../work`) or the product checkout; when no checkout of that repo is on disk, the line reads `unchecked: <path> (no cosmic-lua/work checkout beside this one)` rather than `absent`. Test in the show verb's test file: a work-repo item read from a fixture product checkout with a sibling work clone reports the path present; with no sibling, `unchecked`.

## Non-goals

No change to what `absent:` means for a path that truly is not in the item's repo; no network fetch to check a path.

## Access

cosmic-lua/work, read and write on a branch; no other repository.

## Ready when

`gitboard show CM0F_Tk4k` from the cosmic checkout prints no `absent:` line for `_work/brief.tl`, and a fixture with no sibling prints `unchecked:` instead.
