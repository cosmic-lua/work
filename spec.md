## Evidence

Builder «qPiX_DdxS» (cosmic#1751, 2026-09-06): "`--make ci` failed on
`_build/casts_test.tl`, `_build/nil_returns_test.tl`, then
`_build/cast_sites_test.tl` — none mentioned in the spec — costing
three extra full `--make ci` runs (~2.5 min each) … Each failure's
error message named the exact fix, so it was self-solving once hit."
Builder «Hkal_OAFy» (cosmic#1750) ran the same regen pair because its
spec named it. The cosmic tree ratchets casts, nil-returns, cast-site
classes, coverage rows and doc paths per file; every ratchet's failure
line prints its own regen or edit command, and each is a per-file test
that runs in seconds — but the builder brief's step 3
(`_work/brieftext.tl`, "run the full gate once, before the push") sends
a builder back to the full gate after each one, so N ratchets cost N
full gates. Three of five cosmic builders this pass paid at least one.

## Change

`_work/brieftext.tl`, builder step 3: after "run the full gate once,
before the push", add: "When the gate fails on a `_build/*_test.tl`
ratchet (casts, nil-returns, cast-sites, coverage rows, doc paths), the
failure line names its own fix — run that regen or make that edit, then
re-run only that test file (`bin/cosmic --make test _build/<name>_test.tl`),
and go back to the full gate only when every ratchet you tripped is
green on its own. A ratchet row you add is part of the diff, not scope
creep: say so in the PR body." `_work/brieftext_test.tl`: the template
contains "re-run only that test file".

`gitboard help bar` (`_work/doctrine.tl`, the bar topic): one sentence
under "Measured, not inferred" — a Change that adds a cast, a
nil-admitting return, or a new source file names the ratchet rows it
will add, so the builder's first gate is its last.

Step 5 of the same template, one more sentence from the same pass (builder
«VGEI_R3nE» wiped its uncommitted edit with the `git checkout --` that undid
its mutation): "Commit the real change before mutation-testing it, so a
checkout-restore used to undo the mutation cannot wipe it too."
`_work/brieftext_test.tl`: the template contains "Commit the real change
before mutation-testing".

## Non-goals

No change to any ratchet. No change to the review brief.
