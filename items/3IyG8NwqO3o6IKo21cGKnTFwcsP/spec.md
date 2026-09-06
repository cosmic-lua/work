## Evidence

`help bar`'s third sentence from #60 is conditional — `git grep -n
'structural finder' -- _work/doctrine.tl` → 151 "Where the tree has a
structural finder, a Change over N sites states the PATTERN…" —
because `cosmic --find` did not exist when it was written. It does
(cosmic#1763, 2026-09-06): `o/bin/cosmic --find 'check.must($X)' _cli`
→ `find: 83 hit(s) in 48 file(s)` in one call. The review brief has
no step that re-runs a spec's pattern against the PR head (`git grep -n
'find' -- _work/brieftext_review.tl` → no hit), so a sweep PR is still
judged by reading the diff.

## Change

`_work/doctrine.tl`, the bar's third sentence, unconditional: "A
Change over N sites states the PATTERN that selects them and the count
`cosmic --find PATTERN [PATH...]` printed — never a list of file:line
pairs a builder re-derives." `_work/brieftext_review.tl`, `REVIEW`
step 2, one sentence: "When the spec states a pattern and a count,
re-run `cosmic --find` on the PR head from your checkout: the hit list
IS the expected change set — a hit the diff leaves unchanged, or a
changed site outside the hits, is a finding." `_work/doctrine_test.tl`
and `_work/brieftext_test.tl`: each contains its sentence; the
"structural finder" assertion is replaced.

## Non-goals

No change to `--find` itself; no requirement on specs over fewer than
N sites.
