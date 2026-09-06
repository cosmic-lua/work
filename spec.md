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

`_cli/reads_lint.tl`: a second finding under the same rule name. A `reads:`
entry under `o/` is a build OUTPUT unless it is a pre-graph input, and only
pre-graph inputs may be declared. The two pre-graph shapes, both stated
in AGENTS.md ("generators run before the graph"; the trust-root artifact
"no verb reproduces"), are: `o/bootstrap/**` (the pinned cosmic `bin/cosmic`
downloads before any verb), and `o/<dir>/<stem>_gen/**` where
`<dir>/<stem>_gen.tl` exists in the tree and is not a `cmd/<name>/embed_gen.tl`
(a binary's payload generator packs what the graph produced, so it runs LAST
and its output is exactly the case this rule refuses). Every other `o/…`
entry is reported at the header's line: `reads-declaration: <file>:<line>:
`reads: o/…` names a build output, which does not exist on a cold tree;
derive it in-process from the tree (the generator's own module) or declare
the SOURCES it is built from`. Measured on main (2026-09-06, builder
«CBMu_etpH» first attempt): the lexical rule flagged `_build/coldbuild_test.tl`
(`o/bootstrap/cosmic`, `o/_types/types_gen`), `_build/pin_probe_test.tl`,
`_perf/skew_test.tl`, `_tool/seam_test.tl` (`o/bootstrap/cosmic`) — all
legitimate pre-graph inputs, none to be edited; the refined rule flags none
of them and still flags `o/cmd/cosmic/embed_gen/embed/.docs/index.lua`.
`_cli/reads_lint_test.tl`: one case each for `o/x` (flagged), bare `o`
(flagged), `o/bootstrap/cosmic` (allowed), `o/_types/types_gen` (allowed
when a fixture `_types/types_gen.tl` exists beside the test's root),
`o/cmd/hello/embed_gen/x` (flagged even though `cmd/hello/embed_gen.tl`
exists), and a path merely containing `/o/` (not flagged).
`docs/guides/lint.md`, the `## reads-declaration` section: one paragraph
with the message, the two allowed shapes and the reason. `gitboard help
bar` gets nothing — the lint is the gate.

Gate: `bin/cosmic --make ci` — which now also proves the refined rule
flags nothing on the current tree.
## Non-goals

No change to `_make/imports.tl`'s refusal — it stays as the backstop.
No widening of the rule to non-test files.
