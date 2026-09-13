- Not touching `_build/public_surface.tl`'s tree-side `modules()` — it
  already gates on `init.tl` and is the reference this change matches.
- Not changing what counts as public (`cosmic/doc/visibility.tl`) — this
  is only about which directories `surface_test.tl` hands to that rule.
- Not adding a cross-check test asserting the embedded-side and
  tree-side rules agree with each other in general (beyond the existing
  `test_index_visibility_agrees_with_the_rule`, which covers a different
  pair of surfaces — the doc index and `visibility.is_public`); the fix
  here is bringing one rule to parity with the other's already-settled
  behavior, not adding new machinery to keep them in sync going forward.
