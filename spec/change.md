`docs/design/casts.md`: replace the hand-written total with the current
sum (measure: count rows per class in `docs/design/cast-sites.tsv`, sum
the five floor classes, state the command in the sentence's footnote or
the reconcile output). `_build/cast_sites.tl --reconcile`: also
rewrite that one sentence from the table (the same way it reconciles
rows), so the prose total is derived, and `_build/cast_sites_test.tl`
asserts the sentence equals the sum. Gate: `bin/cosmic --make ci`.
