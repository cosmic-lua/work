## Evidence

`cosmic --rewrite PATTERN REPL --fix PATH...` (cosmic#1766) applies a
pattern over many files in one process, but two shapes the tree's own
sweeps need cannot be written as a pattern yet, measured 2026-09-06:
- `grep -lE '^test_[a-z_0-9]+\(\)\s*$' $(git ls-files '*_test.tl') |
  wc -l` → 12 files still call their tests at the bottom (the legacy
  shape D29 retires); the rewrite is "delete the statement `test_*()`",
  which needs a capture that matches a NAME by prefix (`$F()` matches
  any call, `test_$X()` desugars to a plain identifier) and an empty
  replacement that removes the whole statement, not its text.
- `o/bin/cosmic --find 'require("cosmo.unix")' cosmic/*_test.tl
  cosmic/*_example.tl` → 4 sites AGENTS.md forbids; each becomes a
  `cosmic.*` wrapper call, a per-site rename that a name-filtered
  capture expresses in one pattern.
`cosmic/ast/match.tl` binds a capture to any node of kind
`variable`/`identifier` (`grep -n 'kind.*identifier' cosmic/ast/match.tl`).

## Change

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
parses. Then run it: `--rewrite '$F:^test_()' '' --fix` over the 12
files above IS the acceptance — the diff of that run, formatter-clean,
lands in the same PR, and `grep -lE '^test_[a-z_0-9]+\(\)\s*$'` → 0.

## Non-goals

No type-aware predicates; no multi-pass application.
