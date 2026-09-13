One rule replacing the line reader: `_tool/lint.tl`'s `is_justified`
takes the site as an AST call node (from `cosmic.ast.parse` +
`cosmic.ast.walk`, callee name `assert`, `error`, `os.exit`, or a
`cast` node) and reads the token stream's comment attached to the
token following the node's end (`span_end`), or to the node's first
token when the marker sits on the line above — the same two
placements as today. `_cli/lint.tl` walks the file once and feeds
every such node; `error` demands `-- throws:`, `os.exit` demands
`-- exits:`, `assert` in library source demands `-- assert:`, `as`
demands `-- cast:`. `_tool/lint_test.tl`: an `error(` with no marker
in `cosmic/x.tl` → a finding; with `-- throws: why` → none; an
`assert(` inside a string literal → none; the four existing cases
unchanged. The 47 `error(` and 49 `os.exit(` sites that lack a marker
are NOT fixed here: the rule lands with a baseline count per path
(`_build/throws_baseline.tl`, the same shrink-only shape as
`casts_baseline.tl`), and «a follow-up sweep item» burns it down with
`cosmic --find`.
