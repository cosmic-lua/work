## Goal

`cosmic.ast.match`'s original Goal named a novel axis neither
ast-grep nor comby has: "because `tl.check` produces a fully typed
AST, matching can eventually filter by inferred type, not just syntax
shape" (`«HpoM_Gzj7»`). Never built — `«5P4r_VUqR»` (`cosmic --find`)
lists "no type-filtered matching" as an explicit Non-goal, and
`o/_types/types_gen/tl.d.tl` exposes no `check`/type-report surface at
all today (`grep -n "^  check\|TypeChecker\|infer_at\|type_of" tl.d.tl`
— zero hits; the narrowed public `tl.d.tl` cosmic generates covers
`lex`/`parse_program`/a few others, not the checker's internals).

This is a research item, mirroring `«HlZW_zWbs»`'s own shape (a
completed investigation into a related, harder question — see
Findings below): the deliverable is a settled answer to whether
`tl.check`'s type information is reachable and usable for pattern
filtering at all, plus follow-up items if it is. Not a build
commitment.

## Why this is genuinely open, not a small addition

`«HlZW_zWbs»` investigated a DIFFERENT but adjacent question (does
`tl`'s checker expose stable per-declaration identity, for semantic
rename) and found the closest-looking API,
`tl.symbols_in_scope`/`TypeReporter`, answers a type-report question
("what type does this position have"), not a binding-identity one —
confirmed by direct test, not inference. Type-FILTERED matching needs
exactly what that layer might plausibly provide (a type per AST
position), which is a different question from what `«HlZW_zWbs»` ruled
out (identity per declaration) — so that finding does not settle this
one either way, and this item cannot skip its own direct investigation
by citing it.

Concretely open:
- Does `tl.check`'s `TypeReporter`/`symbols_by_file` machinery
  (`tl.lua:6500-6546`, `:6306`, cited in `«HlZW_zWbs»`'s Findings)
  expose a queryable type per node position, callable from outside the
  checker's own pass, cheaply enough to run per pattern match rather
  than once per file?
- What would a pattern's type-filter syntax even look like — a
  `$X:type<pattern>` predicate analogous to the existing
  `$T:<lua pattern>` rendered-type-text predicate `cosmic.ast.match`
  already has for CAST target types specifically (`cosmic/ast/match_cast.tl`),
  generalized to any capture, or something shaped differently because
  a general expression's type isn't rendered as source text the way a
  cast's target type annotation is?
- Cost: `tl.check` is a heavier pass than `tl.parse_program` alone
  (full type inference, not just parsing) — every existing
  `cosmic.ast` consumer (`--find`, `--rewrite`, the casts lint) parses
  today; would type-filtered matching require re-running `check` per
  file even for a plain, non-type-filtered pattern, or can the two
  stay decoupled so only a pattern that actually asks for a type
  filter pays the cost?

## What to investigate

Read `o/3p/tl/tl.lua` directly (not `tl.d.tl`, which is cosmic's own
narrowed surface and may not expose what's needed) for how `tl.check`
exposes per-node type information, whether it is queryable
post-check by position the way `«HlZW_zWbs»` needed per-declaration
identity to be, and whether it is reachable from a `require("tl")`
caller without vendoring internals the carried-patch mechanism would
need to expose. Settle with a direct test against a real fixture
(`tl.process_string` + whatever the checker actually returns), the
same empirical standard `«HlZW_zWbs»` held itself to — not inference
from reading the grammar alone.

## Non-goals

Not building the feature. Not committing to a pattern-grammar syntax
before the underlying data is confirmed reachable. Not re-investigating
`«HlZW_zWbs»`'s own question (binding identity) — cite its Findings,
don't repeat its experiments.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.
