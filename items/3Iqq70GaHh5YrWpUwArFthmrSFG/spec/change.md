One edit to `_make/fixpoint_test.tl`: `seed_pins` also seeds the
trust root — copy `o/bootstrap/cosmic` (and `o/bootstrap/cosmic.pin`
beside it, which `bin/cosmic` reads to decide whether the cached
bootstrap matches the pin) into the copied tree, with a comment
saying why: a declared read must exist for the build to start, and
`_build/coldbuild_test.tl` declares the bootstrap. Add both to the
`want` table (`:107-118`) as `{"bootstrap", "cosmic",
"o/bootstrap/cosmic"}` / `{"bootstrap", "cosmic.pin",
"o/bootstrap/cosmic.pin"}`, or a sibling list if the tuple's first
two fields are used to name the pin in a message (read `:119-129`).
The two generations then run to `test_the_fixpoint_converges`.

Proof: `COSMIC_FIXPOINT=1 bin/cosmic --make test _make/fixpoint_test.tl`
ends `test: PASS`, and `bin/cosmic --make ci` ends `ci: PASS`.

Wall: no change to `_build/coldbuild_test.tl`'s declaration; a
declared read that does not exist staying a refusal is the point.
