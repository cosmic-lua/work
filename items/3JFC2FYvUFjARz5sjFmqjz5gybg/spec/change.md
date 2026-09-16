Make brief's mechanical classifier conservative across repository profiles.
Keep changed additions+deletions below 20 as an unconditional mechanical
shortcut, including product-source changes in cosmic and make profiles.
At 20 or more lines, use a profile-owned proof of non-product paths:
for the cosmic profile, require every changed file to match the existing
*_test.tl convention; for make or absent/unknown profiles, no current
classification contract proves non-product paths, so select full review.
Empty or otherwise indeterminate path evidence must not prove test-only.

Put this proof in _work/repoprofile.tl and use the already resolved product
checkout's profile in _work/brief.tl. Do not make a second source-extension
list or use cosmic's internal project.classify for C: that API classifies
ordinary C/header/assembly as assets. Unknown paths fail closed to full
review. This deliberately routes large documentation-only changes and
large make test changes to full review until a repository-owned proof
contract exists; adding that contract is outside this item.

Retain the current small-diff threshold and cosmic large *_test.tl-only
exemption. A mixed test/product diff at or above the threshold selects full
review. Preserve local Git inspection, frozen review range, product-root
resolution and current behavior on failed local inspection.

Regression coverage must use real local product commits and cosmic/make
profile fixtures: 19 versus 20 lines; small product changes in both profiles;
large cosmic source versus cosmic test-only; large C, header and assembly
changes; mixed test/product; large docs; and missing/unknown profile. Check
rendered script/full routing as well as the profile predicate. A synthetic
make fixture is sufficient; do not assume cosmopolitan's actual Makefile
advertises a profile contract that has not been inspected.
