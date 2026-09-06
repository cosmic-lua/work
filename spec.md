## Evidence

PR cosmic#1775 (head bffb39a) widened three existing cross-module calls by one optional parameter (`check.run` → `handle_check_style` → `lint_file`, all under `_cli/`). `bin/cosmic --make ci` was green in the builder's warm worktree and `_build/coldbuild_test.tl` passed, yet the `build` lane failed in generation 1: `o/bootstrap/cosmic: /zip/main.lua:45: error loading module '_cli.main_handlers' from '…/_cli/main_handlers.tl': _cli/main_handlers.tl:383:37: error: wrong number of arguments (given 2, expects 1)` (run 34066460175, job 101575960880). Reproduced locally by removing everything under `o/` except `3p/` and `bootstrap/` and running `bin/cosmic --make build`: identical error; the first attempt with a populated `o/` did NOT reproduce, because the pin loads already-compiled `o/_cli/*.lua` without type-checking. The pinned release type-checks a tree module it loads against its OWN embedded snapshot of the sibling (`.types/`), not the tree's `_cli/lint.tl`, so any arity change on a call between two modules the release already ships fails a cold build until a release carries the new signature — the same staging AGENTS.md documents for checker changes, but nothing says it for signatures, and the cold-build ratchet did not fire. The fix that landed: carry the new value in a new module (`_cli/lint_limit.tl`), which the snapshot has never seen and so is checked from the tree.

## Change

Two things. (1) `_build/coldbuild_test.tl` models generation 1 as it is: the pinned release's embedded `.types` snapshot AHEAD of the tree on the include path for every module the release ships, so a widened call between two shipped modules fails the test in the warm worktree where the builder sees it, with a message naming the staging rule ("`<caller>` calls `<callee>` with N args; the pinned release's `<callee>` takes M — a signature change on a shipped module stages behind a release and pin bump, or moves into a new module"). (2) AGENTS.md's cold-build paragraph gains one sentence stating the rule for signatures, not only checker changes, and naming the new-module escape.

## Non-goals

No change to convergence, no change to what the pin ships, no relaxation of the type check.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.

## Ready when

`_build/coldbuild_test.tl` fails on a fixture (or on the tree with `lint_file` widened by one optional parameter and one caller passing it) with the message above, passes on main, and the AGENTS.md sentence is present.
