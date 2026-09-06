## Evidence

PR cosmic#1775's reviewer deleted the one line in `cmd/cosmic/main.tl` that records `--max-lines` (`require("_cli.lint_limit").set(opts.max_lines)`) and both test files the PR added (`_cli/lint_test.tl`, `_cli/parse_test.tl`) stayed green: each reads or writes `opts`/`lint_limit` directly and never calls through `main()`. Only running the built binary showed it — `o/bin/cosmic --check lint --max-lines 10 twelve.tl` on a 12-line file reported `file-length: … (limit: 10)` on the head and `Style check passed` with the mutation. No test in the tree drives `cmd/cosmic/main.tl`'s `--check` dispatch end to end (`grep -rn 'max-lines' _cli/*_test.tl cmd/` → the two unit tests only).

## Change

One end-to-end case, in the file that already runs the built binary as a subprocess for other flags (`_cli/help_test.tl` or whichever `*_test.tl` spawns `o/bin/cosmic` — measure first), that writes a 12-line `.tl` under `TEST_TMPDIR`, runs `cosmic --check lint --max-lines 10 <file>` through `cosmic.proc`, and asserts a non-zero exit with `limit: 10` in the output, plus the same file passing with no flag. Deleting the `lint_limit.set` line in `main.tl` must fail it.

## Non-goals

No change to the flag, the module, or the recipe.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.

## Ready when

The new case passes on main and fails when `cmd/cosmic/main.tl`'s `lint_limit.set(opts.max_lines)` line is removed.
