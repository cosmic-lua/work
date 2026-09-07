## Goal

Scope whether `cosmic/format`'s token-window type/block detection
should move onto `cosmic.ast` spans, and produce enough evidence for a
`decide` record — this item's own parent (`Pzk1_xFDD`) names that
record as the gate before any rewrite lands ("a decision this size...
goes through `decide` once the dependency lands and someone scopes it
for real"), and its own dependency (`cosmic.ast.node`/`.walk`) is now
`done`. This is a research item: its deliverable is a recorded
finding plus follow-up items, not a formatter rewrite.

## What to spike

Pick the single heuristic category `cosmic/format/types.tl` itself
names as the hardest: TYPE-position detection across a line break
(`mark_carried_type`, `opens_type_position` — the "one carried bit"
its own header comment calls "the whole difficulty"). Build a
throwaway probe, not a landing change:

1. For every `.tl` file this repo's own project walk covers, parse
   with `cosmic.ast.parse`, and for every node whose Teal grammar
   position is a type annotation (a `local`/`global`/parameter's `:`
   type, a cast's `$T`, a generic's parameter list), record its
   `span_start`/`span_end` byte range.
2. Independently, run the CURRENT token-window `type_marks` over the
   same file and record which token indices it marks as belonging to
   a type.
3. Diff the two per file: does the AST-derived range agree with the
   heuristic's marks, token-for-token? Report disagreements with
   `file:line`, not just a count — the goal is to find whether
   disagreement clusters in the shapes `types.tl`'s own comments
   already name as past regressions (a wrapped function type, a
   comment inside a carried type, `record`/`enum`/`interface` as a
   key) or turns up NEW shapes neither the heuristic nor its authors
   anticipated.
4. Time both passes over the same file set (`cosmic.ast.parse` +
   walk vs. the existing token-window scan) — the formatter runs on
   every `--check fmt`/`--make fmt` invocation in the gate, so a
   per-file cost regression here is a tax on every CI run, not a
   one-time cost.

## Non-goals

Not a rewrite. Not touching `cosmic/format/types.tl` or `rules.tl`.
Not deciding to proceed — that decision, and its record, is the
deliverable this research feeds, per the parent item's own Non-goals.
Not attempting the OTHER two heuristic categories the parent names
(block-opener detection, generic-parameter-list marking) — if the
type-position spike shows the approach is sound, those are smaller
and follow the same method; if it shows the approach is NOT clearly
better (disagreement is rare, or the AST pass is materially slower on
this repo's own large generated files), that finding alone settles
the `decide` record without spiking the other two.

## Ready when

`gitboard show 0E11_GJmv` and `gitboard show gDNw_5bFk` both show
`state: done` (already true at filing time — this item is pullable
now).

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.
