## Evidence

`_work/overlap.tl`'s `change_section` (lines 45-59) reimplements
`_work/spec.tl`'s `sections` (lines 42-56) — the same line-by-line
heading/thematic-break scanning loop, character for character in
structure — narrowed to return only the `"change"` key's text instead
of the full heading map. `overlap.tl`'s own doc comment on
`change_section` already names this: "the same heading-scanning
`_work.spec.sections` runs for the spec bar, narrowed to the one
heading this module reads" — the duplication was noticed at write time
and left in place rather than reused.

`overlap.tl` does not currently import `_work.spec` (`grep
"^local.*require" _work/overlap.tl`: `cosmic.fs`, `_work.tail` only) —
the duplication was presumably to avoid that dependency, but `spec.tl`
itself has no import of anything overlap-related, so there is no cycle
risk in adding it.

## Change

1. `_work/overlap.tl`: add `local spec = require("_work.spec")`, delete
   `change_section`'s scanning loop, replace its one call site
   (`paths_named`) with `(spec.sections(spec_text)["change"] or "")`.
2. Delete `change_section` entirely — nothing else calls it
   (`grep -rn change_section _work/*.tl`).
3. Re-run `_work/overlap_test.tl` unchanged — behavior does not move,
   only which function produces it.

## Non-goals

Changing `sections`'/`ready_gaps`'s own behavior; the separate,
already-filed promotion of `sections`/`ready_gaps` into a public cosmic
markdown-utilities module — this item is the internal fix regardless of
whether or when that promotion lands, since the duplication is a fact
about this repo's own code today.
