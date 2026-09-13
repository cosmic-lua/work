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
