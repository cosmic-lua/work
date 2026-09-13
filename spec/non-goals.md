No assertion changes: every `assert_format`/`assert_format_fails`/`assert_idempotent`
call keeps its input, expected output and message byte-identical, and
the total assertion count must not move. No formatter behaviour
change, and no change to `cosmic/format/init.tl`, `rules.tl` or
`types.tl`. No change to `_tool/discover.tl`'s classification rules as
a way of dodging the question. No renames of `assert_format` or
`assert_idempotent` in either file, and no reference (silencing or
otherwise) to `assert_format_fails` in `regressions_test.tl` — it is
simply absent from that file, matching the precedent that a file
duplicates only what it calls. No reflow of assertion bodies beyond
the indent their new enclosing function requires.
