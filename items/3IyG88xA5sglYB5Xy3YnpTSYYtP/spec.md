## Evidence

The justification-marker reader is a string match on the site's line
(`_tool/lint.tl:54-64` `is_justified`, pattern `"%-%- " .. marker ..
": %S"`), and only `cast` and `assert` markers are read (`:52` "The
marker word: `cast`, `assert`"). D30 also requires `-- throws:` on
every library `error(` and `-- exits:` on every `os.exit(`, and nothing
gates them: `o/bin/cosmic --find 'error($$$A)' cosmic` → 47 hits,
`--find 'os.exit($$$A)' cosmic` → 49, `--find 'assert($$$A)' cosmic` →
6835 (tests included; the library subset is what the rule judges). A
line match also fires on `assert(` inside a string or a comment.

## Change

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

## Non-goals

No new marker words; no change to what a valid reason is.
