To be scoped at refinement. Candidate directions:

- Zero-initialize the allocation (`calloc`-equivalent, or explicitly
  NUL-terminate the array immediately after allocation, before the
  conversion loop begins) so an early `FreeStringList` call is always
  safe regardless of where the loop stops.
- And/or NUL-terminate the array up to the failed index before calling
  `FreeStringList`, so it only ever walks the valid, already-converted
  prefix.
- Either fix should convert this crash into the clean `luaL_argerror`
  (an argument-shape violation — a non-string element in an argv/envp
  array is exactly the "degenerate input no correct program passes"
  class this repo's own binding-contract rule already routes through
  `luaL_argerror`, not a silent crash or a fallible-tuple return).
