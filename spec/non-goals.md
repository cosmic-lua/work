- **Do not add `e` to `cosmic/literal.tl`'s `ESCAPES`.** Settled
  above: the reader stays stock Lua. `cosmic/literal.tl` is not
  edited by this item at all.
- **Do not touch whilp/cosmopolitan.** `cosmo.EncodeLua` spelling
  byte 27 as `\e` is a frozen C-boundary behaviour and is
  self-consistent with the `load` beside it; the fix is on the cosmic
  side of the boundary.
- **Do not change the pin layout.** It round-trips all 256 bytes in
  both positions today (Evidence) and must keep doing so.
- **Do not change any refusal message or return shape** in
  `cosmic/_literal_format.tl`. A value the compact writer declines is
  handed to the pin layout, not refused to the caller — that is the
  existing behaviour and it does not move.
- **Do not fix `3ICDKhO3`** (the depth-33 inline-render break, domain
  bound 1 in the same comment). It is a separate item and its bound
  stays.
- **Do not widen the fuzz alphabet or iteration count.** The only
  fuzz edit is removing bound 4 and its two constants.
