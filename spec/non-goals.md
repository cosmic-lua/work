- no corpus persistence (`testdata/`, a sibling child), no crash
  isolation via `cosmic.child` (a sibling child), no coverage-guided
  generation, no discard accounting (`assume()`), no `cosmic.fuzz`
  publishing move. `_fuzz/shrink.tl` stays internal to `_fuzz`, same
  as `_fuzz/source.tl`.
- does not classify failures by cause: a candidate that fails `check`
  for *any* reason (a different assertion, a different thrown error,
  even a budget-exceeded from `driver.arm_budget`) counts as "still
  fails" during shrinking. A shrunk report describing a different
  failure than the original is a known limitation of this slice, not
  a bug to fix here.
- does not change `_fuzz/source.tl` — `Draw`, `new`, and `replay` are
  read-only inputs to this slice.
- does not touch the six `*_fuzz_test.tl` generator bodies.
- no change to `Options`, `bytes`, or `mutate`.
