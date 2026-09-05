## Change

New `cosmic/ast/match.tl` (public, `cosmic.ast.match`), depending on
`cosmic.ast.node`. Port from `docs/design/ast-rewrite/tlgrep.tl`
(branch `claude/teal-search-replace-1xq19s`):

- `desugar(pattern_src: string): string` — rewrites ast-grep-style
  `$NAME`/`$$$NAME` metavariables into valid Teal identifiers
  (`_NAME`/`___NAME`) via plain string substitution BEFORE lexing,
  since `$` is not a legal Teal identifier character and the pattern
  must parse as real Teal to become a real AST to match against. Safe
  because pattern text is only ever matched, never spliced back into
  anything, so shifting its byte positions has no effect on output.
- `compile_pattern(pattern_src: string): Node | nil, string` — desugars,
  parses, and unwraps the one-statement program `tl.parse` produces
  into the pattern's own top node (a bare expression parses as a
  statement whose statement IS the expression; a statement pattern
  like `if ... end` needs no unwrap either way — `program[1]` is
  already the right node in both cases).
- `match(pattern: Node, node: Node): {string: Node} | nil` — the
  matcher itself, one fully generic recursive function
  (`match_value` in the spike): every named field the PATTERN
  specifies must match; unspecified fields are ignored (subset
  matching), so `if $C then $$$BODY() end` falls out of the SAME
  recursion that handles `f($A, $B)` — no per-kind special-casing. Two
  capture shapes: a bare `$X` (desugared `_X`) can appear as a
  `variable`-kind node (a value position, `f($X)`) OR an
  `identifier`-kind node (a member-name position, `cosmo.$X(...)`) —
  this session found by direct testing that a capture check gated on
  `kind == "variable"` alone silently matches nothing in member
  position, since `tl`'s own grammar tags a dotted member name as
  `identifier`, not `variable` (confirmed:
  `cosmo.$F($$$ARGS)` returned 0 matches against real `cosmo.Slurp(...)`
  call sites until the check was widened to accept either kind — port
  the widened check). A rest-capture (`$$$NAME`) matches zero or more
  trailing elements of an array-shaped field (call args, a block's
  statement list) — in a STATEMENT-list position it must be spelled
  `$$$NAME()` in the pattern (a zero-arg call), not bare `$$$NAME`,
  because Lua/Teal has no bare-expression-as-statement syntax; the
  matcher recognizes both surface shapes (see `rest_capture_name` in
  the spike).
- The matcher needs its own identity-keyed cycle guard (a `seen` table
  threaded through, NOT shared with the walk module's) — confirmed by
  reproducing an actual infinite-recursion risk via `if_block`'s
  `if_parent` back-reference before the guard was added; `tk`-field
  comparison must be excluded from the generic field walk EXCEPT on
  `variable`/`identifier`/`string` leaves, since on a compound node
  (`statements`, `if_block`) `tk` is just whichever token happened to
  open it and differs incidentally between pattern and target even on
  a genuine match (confirmed: an `if $C then $$$BODY() end` pattern
  matched nothing until `tk` was added to the generic ignore-list).

## Non-goals

No span/splice logic (depends on the walk item, kept separate), no
project-wide file traversal (the CLI item's job), no type-aware
matching (a real v2 needing `tl.check`'s typed env — out of scope for
the syntax-only matcher this item builds; note it as a clearly separate
future item if picked up later, don't fold it in here).

## Acceptance

Reproduce, as `cosmic/ast/match_test.tl` cases, the concrete patterns
this session actually ran against real files and got real counts for
(re-run each at pull time against the CURRENT tree and update the
counts if they moved):
- `os.execute($X)` against `_types/tlast.tl`: 1 match,
  `os.execute(cmd)`.
- `string.format($FMT, $$$REST)` against `cosmic/check.tl`: 5 matches
  (variable arity: 2, 2, 1, 2, and 1 trailing args after the format
  string).
- `if $C then $$$BODY() end` against `cosmic/check.tl`: 25 matches
  (every `if` with no `elseif`/`else`).
- `cosmo.$F($$$ARGS)` against `_tool/doc/index.tl`: 2 matches
  (`cosmo.Slurp(file_path)`, `cosmo.EncodeLua({modules = modules})`),
  the identifier-position-capture regression case above.
