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
