## Goal

`cosmic/format/types.tl` and parts of `cosmic/format/rules.tl` exist to
re-derive, heuristically, from a flat TOKEN WINDOW, facts that
`tl.parse_program`'s AST already answers directly: whether a span of
tokens is a TYPE rather than code (`mark_carried_type`,
`mark_return_list`, `mark_function_type`, `mark_parenthesized_types`,
`type_marks`, `opens_type_position` — all of `cosmic/format/types.tl`),
whether a `function`/`record`/`enum`/`interface` keyword opens a block
or is an ordinary identifier in that position
(`is_block_opener`/`is_function_block_opener`), and where a generic
parameter list starts and ends (`mark_type_params`). Nearly every
function above carries a comment describing a real regression this
heuristic reconstruction caused and then had to be patched around
(`record`/`enum`/`interface` used as a table key or a call read as a
block opener; a wrapped function type's carried bracket depth; a
comment between `:` and its type resetting a carried bit) — the AST
never has these ambiguities, because the parser already resolved them
during parsing.

This item is filed because two current formatter bugs (filed
alongside it: the `- -1` regression and the `<const>`/generic-record
spacing gap) are both instances of the SAME underlying shape — the
token-window approach has no structural notion of "this is one type",
"this is one attribute list", "this is one generic parameter list", so
each new shape needs its own hand-written detector, found by hitting
it in real code. A real `Node` type with real spans removes the
category, not just the two known instances of it.

Separately, the `cosmic.ast` outcome (`«HpoM_Gzj7»`, unranked) is
building exactly the primitives this would need: `cosmic.ast.node`
(`«0E11_GJmv»`, a real `Node` record over `tl`'s parser output) and
`cosmic.ast.walk` (`«gDNw_5bFk»`, a cycle-guarded walk plus
`span_start`/`span_end` — already hardened against the `yend`/`xend`
unreliability that would otherwise bite a formatter rewrite the same
way it bit the `cosmic.ast` spike). That outcome's own design
explicitly treats `cosmic.format` as a fixed dependency it calls
into (`cosmic.ast.rewrite` pipes spliced text through
`cosmic.format.format`), not something it changes — so nothing there
currently proposes reusing that infrastructure for the formatter
itself. This item records that option for whoever ranks `cosmic.ast`
next, rather than leaving it to be rediscovered.

**Ready when:** `cosmic.ast.node` and `cosmic.ast.walk` are both
`done` — check `gitboard show 0E11_GJmv` and `gitboard show
gDNw_5bFk` for `state: done` (or their absence from `todo`/`doing`
with a `pr:` resolved). Until then this item is not buildable; it
exists to be found, not pulled.

## Non-goals

Not deciding to do this — a decision this size (replacing a
CI-gating tool's core structural analysis) goes through `decide`
(`skills/decide/SKILL.md`) once the dependency lands and someone scopes
it for real, not through this item alone. Not touching
`cosmic/format` now. Not assuming the AST approach nets out simpler
before someone actually measures a spike against real files the way
the `cosmic.ast` spike itself was measured before being proposed as a
real module — this item's job is to make the option visible and name
its dependency, not to pre-judge the tradeoff.
