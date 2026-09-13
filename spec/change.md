`docs/decisions/d43-<slug>.md`: a new record in the four-section
form the `decide` skill prescribes (`skills/decide/SKILL.md`; the H1
grammar the index derives from). The tradeoff: generation 1 takes its
CHECKER from `bin/cosmic.pin` but its `cosmo.*` declarations from the
tree's own `3p/cosmos` pin, via a seed pass, so a cosmos contract
change stages behind a cosmos pin bump alone and never behind a cosmic
release. What was given up: the trust root's bundled types are no
longer what a cold build checks against, and a change to the upstream
annotation FORMAT now stages like a checker change (land it in
`_types/gentype.tl`, ship a release, bump `bin/cosmic.pin`, then bump
the cosmos pin). Name the two pins and the two staging rules
explicitly; cite no board ids, PR numbers or sessions in the record
(docs-style: no history references).

`docs/decisions/README.md`: regenerate the derived index the way the
`decide` skill says the index is produced; never hand-edit a row.

`CLAUDE.md`, the "cold-build rule" paragraph: add one sentence after
"with the pinned release's checker and patch set": the cosmo
declarations it checks against are seeded from the tree's `3p/cosmos`
pin, not the pinned binary, and link the new record. Keep the
paragraph's existing staging example intact.

`_build/coldbuild_test.tl`: read its header comment; if it states that
generation 1 resolves `cosmo.*` from the pinned binary, correct the
sentence — behaviour is «pawY_zI7x»'s change, this item touches prose
and the record only.
