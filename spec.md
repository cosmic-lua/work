## Evidence

Builder «Hkal_OAFy» (cosmic-lua/cosmic#1750, 2026-09-06) reported, out
of scope: `docs/design/casts.md`'s sentence "Together they hold 51 of
the tree's casts today" (the sum of the five floor classes) did not
match the tree before that PR — summing the class counts in
`docs/design/cast-sites.tsv` gives 44. `_build/cast_sites_test.tl`
checks that headings exist and rows are real casts, never that a prose
total equals the table. The builder spent ~6 tool calls deciding
whether casts.md needed an edit at all; a checked total would have
answered in one.

## Change

`docs/design/casts.md`: replace the hand-written total with the current
sum (measure: count rows per class in `docs/design/cast-sites.tsv`, sum
the five floor classes, state the command in the sentence's footnote or
the reconcile output). `_build/cast_sites.tl --reconcile`: also
rewrite that one sentence from the table (the same way it reconciles
rows), so the prose total is derived, and `_build/cast_sites_test.tl`
asserts the sentence equals the sum. Gate: `bin/cosmic --make ci`.

## Non-goals

No change to class definitions or to any cast site.
