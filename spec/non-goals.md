- Does not itself bump `3p/cosmos/cosmos_pin.tl` — that is ordinary
  pin-bump process (`bin/cosmic --make fetch` after updating the pin
  file), ideally batched with other accumulated cosmopolitan contract
  fixes from the same census effort (openpty #311, capget #309,
  isatty #307, the `too_large` %I fix #310, the `Database:serialize`
  crash fix #313, the `ConvertLuaArrayToStringList` crash fix #312) —
  landing them together avoids repeated pin-bump PRs for a burst of
  independent, already-merged cosmopolitan fixes. Whether to batch or
  bump per-fix is the pin-bump PR's own call, not this item's.
- Does not touch `cosmic/quicksand/proxy.tl:81` — confirmed unaffected.
- Does not itself verify PR #315's design (already reviewed and
  merged on the cosmopolitan side) — this item trusts that verdict and
  only tracks the consuming change.
