`cosmic/ast/match.tl`: a capture may carry a Lua pattern predicate on
its name — `$F:^test_` (the text after the first `:` in the
metavariable, desugared into the identifier the same way) — matching
only when the bound node's `tk` matches the pattern; `desugar` and
`compile_pattern` carry it, `match` applies it. `cosmic/ast/rewrite.tl`:
a replacement of exactly `""` on a hit whose node is a statement
removes the statement's whole line range (span_start's line to
span_end's line) rather than splicing an empty string into it.
`cosmic/ast/match_test.tl` and `rewrite_test.tl`: `$F:^test_()` over a
file with `test_a()` and `run()` binds only `test_a`; rewriting it to
`""` leaves no blank line where the call was and the file still
parses. The acceptance is the two test files: the sweep the Evidence proposed is not runnable (see the Evidence amendment).
