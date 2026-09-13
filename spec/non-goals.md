- Not touching `IP_`/`TCP_`/`SO_`/`CLOCK_`'s existing `LoadMagnums`
  calls or their generated types — those four families ARE the
  correct shape for `LoadMagnums` (real extern OS-resolved symbols);
  unaffected precedent, not this item's scope.
- Not exposing `SIG_BLOCK`/`SIG_UNBLOCK`/`SIG_SETMASK`/`SIG_DFL`/
  `SIG_IGN` through `unix.SIG` — they are not signal numbers and stay
  individual fields exactly as today.
- Not the `cosmic-lua/cosmic` cast removal in the same PR as the
  binding change — staged separately once a release carries it,
  tracked as its own item (file when this one is ready to merge,
  mirroring `VHkK_aA5k`'s sibling item exactly).
- Not `unix.fcntl`'s cast, the `zip.open` split, or `CAP_*`
  (`QNQK_p3Wg`) — separate items; note `QNQK_p3Wg`'s own spec still
  points at this item's ORIGINAL (`LoadMagnums`-based) Change as its
  worked template — that pointer is now wrong and needs its own
  correction when `QNQK_p3Wg` is next refined, referencing this
  item's corrected Change instead.
