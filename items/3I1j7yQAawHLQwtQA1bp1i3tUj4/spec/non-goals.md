- Not a rewrite of the six existing `_fuzz/*_fuzz_test.tl` properties. They
  migrate onto the published API as it stabilizes; their properties and the
  found-bug protocol from #1125 are unchanged.
- Does not supersede #1125 or #1134 (scheduled deep-fuzz). This epic is the
  library; those are cosmic's own use of it.
- No public API is frozen before minimization exists — the `Options` contract
  is expected to move, and publishing it early is the thing this epic must not
  do.
