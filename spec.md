## Evidence

`_build/doc_symbols_test.tl` on cosmic-lua/cosmic#1752 (2026-09-06)
declared `--- reads: o/cmd/cosmic/embed_gen/embed/.docs/index.lua`
because its spec said to ("declare the path in the `reads:` line so a
rebuilt index re-runs the test"). The builder's local gate passed on a
warm `o/`; CI's `build` lane, a cold tree, failed in 29 seconds:

    make: _build/doc_symbols_test.tl declares `reads: o/cmd/cosmic/embed_gen/embed/.docs/index.lua`, which does not exist
    build: FAIL (make)

`_make/imports.tl:189-191` is the refusal: a `reads:` entry must exist
when the graph is built, so a build OUTPUT can never be one on a cold
clone — but nothing says so before CI. The `reads-declaration` lint
(`_cli/reads_lint.tl`, documented in `docs/guides/lint.md` "##
reads-declaration") already parses the header for `*_test.tl` files
and runs in `--check lint`, which every builder runs warm or cold.

## Change

`_cli/reads_lint.tl`: a second finding under the same rule name — any
`reads:` entry that is `o` or starts with `o/` is reported at the
header's line: `reads-declaration: <file>:<line>: `reads: o/…` names a
build output, which does not exist on a cold tree; derive it in-process
from the tree (the generator's own module) or declare the SOURCES it is
built from`. `_cli/reads_lint_test.tl`: one case each for `o/x`, bare
`o`, and a path merely containing `/o/` (not flagged).
`docs/guides/lint.md`, the `## reads-declaration` section: one
paragraph with the new message and the reason (the cold-build rule
AGENTS.md states). `gitboard help bar` gets nothing — the lint is the
gate.

Gate: `bin/cosmic --make ci`.

## Non-goals

No change to `_make/imports.tl`'s refusal — it stays as the backstop.
No widening of the rule to non-test files.
