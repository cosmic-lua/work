- **Do not change what any test asserts.** Every existing `assert` keeps
  its condition and its message. The two presence-walk tests in
  `_eval/score_test.tl` and the one in `_eval/stage_test.tl` keep their
  `want` lists and their `meta[field] ~= nil` loops — that is what the
  map-shaped reader is for. A validator that makes an assertion
  redundant is not a licence to delete the assertion.
- **Do not touch `cosmic/json_test.tl` or `cosmic/literal_test.tl`.**
  Those 17 sites are the sibling slice's work.
- **Do not touch any non-test file.** In particular `_eval/score.tl`,
  `_eval/stage.tl`, `_eval/eval_types.tl` and `cosmic/shape.tl` are
  unmoved. `3IOeg86u` has since landed over the first two (PR #1378),
  so this is no longer a race — it is the slice boundary: the non-test
  half of the epic is done and this half touches only `*_test.tl`.
- **Do not change `cosmic.shape`'s contract or add a combinator.** If a
  site needs a shape `cosmic.shape` cannot express, leave that site's
  cast in place, say so in the PR, and file it — do not widen the
  module.
- **Do not add a cast.** This diff removes 21 and adds none. A site that
  will not close keeps its existing `-- cast:` line unedited.
- **Do not edit `_build/casts_baseline.tl` by hand.** Run the regen
  command the gate prints and commit its output.
- **Do not weaken a gate.** No `.cosmicignore` entry, no coverage
  exclusion, no lint suppression.
- **Do not touch `whilp/cosmopolitan`.**
