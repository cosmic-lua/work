Measured 2026-09-16, building «1alS_QzlJ», whose change edits template text in
`_work/brieftext_review.tl` that `_work/brieftmpl_gen.tl` compiles into
committed renderers under `_work/brieftmpl/`.

The builder followed its brief's mutation instruction literally and mutated
the GENERATED file `_work/brieftmpl/posture_diff.tl`. The next
`bin/cosmic --make test` ran the generator step first, regenerated that file
from the untouched source template, and ran the test against unmutated code.
The test passed. The mutation test therefore reported success while having
verified nothing.

The builder noticed and switched to mutating the source template
(`_work/brieftext_review.tl`), which does propagate: the regeneration carried
the break into `_work/brieftmpl/posture_diff.tl` and
`_work/brieftmpl_test.tl` then failed exactly on the new property assertion,
which is the real result. Cost of the detour: about 2 tool calls.

Its own account: "mutating the generated renderer file directly had no effect
— the next `--make test` run's generator step silently regenerated it back
from the untouched source template before the test ever saw the mutation, so
the first attempt 'passed' for the wrong reason (never ran against a broken
renderer) ... `_work/brieftmpl_gen.tl`'s own header comment documents this
repair-then-refuse behavior, but I only found it empirically, not by reading
it first."

Why this is worth a gate rather than a note: the failure mode is a FALSE
NEGATIVE in the one step whose purpose is to detect false negatives. A builder
that does not happen to notice reports a successful mutation test, the PR body
says the guard is real, and a reviewer reading that claim has no cheap way to
tell it was never exercised. The cost is not tokens; it is a quality gate that
silently reports success.

The repository has many generated-and-committed artifacts — every
`*_gen.tl` output, including `_work/brieftmpl/**` and cosmic's own
`o/_types/types_gen/` — so any item touching a template or a type source can
hit this.