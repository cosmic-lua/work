A `wc -l`-based check, surfaced at spec-writing or spec-review time rather
than discovered by the builder: when an item's `## Change` names a file
whose current line count is within ~20 lines of the 500-line cap, the
spec bar (`gitboard help bar` / whatever validates an item before it's
pullable) flags it — either as a hard refusal requiring the spec to note
a repacking/splitting plan, or as a printed warning on `gitboard show`
alongside other spec-bar problems, so a refiner sees it before the item
is pulled rather than a builder discovering it live.

Exact mechanism (orchestrator's suggestion, refiner's call): extend
whatever already computes file-overlap warnhings for `next`'s "overlaps"
annotations (`_work/overlap.tl`?) to also check line-count headroom for
each file an item's spec Change section names, using the same `wc -l`
the `fallible-returns`/file-length lint already enforces.
