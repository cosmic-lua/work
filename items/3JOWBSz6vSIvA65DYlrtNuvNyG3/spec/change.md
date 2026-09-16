Two files now sit at exactly 500/500 against a cap that has no exceptions:
`_work/brief.tl` and `_work/gitboard.tl`. Neither can take a line.

The cap is a property of the MERGE, not of either branch: #177 and #179 each
passed their own gate and produced a 502-line file together, which that
commit's own message records. With two files at the cap, that collision is
now likely rather than hypothetical — any two concurrent items touching
either file collide, and the second one to land pays.

Split both, before the next change lands on either. Find the seam each file
already suggests rather than cutting at a line count: `brief.tl` composes
per-kind fact builders, `gitboard.tl` dispatches. Say in the report which seam
you took and what a reader gains from it, so the split reads as structure
rather than as cap relief.

Two files means this is plausibly two items. Split it if the seams turn out to
be independent; keep it as one only if the same reasoning applies to both.
