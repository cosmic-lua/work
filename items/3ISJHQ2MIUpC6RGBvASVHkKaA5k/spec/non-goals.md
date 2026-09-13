- Not `zip.writer`/`zip.appender` — already landed, untouched here.
- Not `unix.fcntl`'s per-cmd split — that needs a `cosmic.fd` API
  decision this item's evidence does not make (typed accessors vs. the
  existing generic escape hatch); tracked as a separate item.
- Not removing `cosmic/zip.tl:222`'s cast — that is
  `cosmic-lua/cosmic`'s side, and per this repo's own staging rule (a
  `cosmic-lua/cosmopolitan` binding reaches `cosmic-lua/cosmic` only
  once a `cosmos` release carries it and `3p/cosmos/cosmos_pin.tl` is
  bumped), it cannot land in the same PR as this one. Tracked as a
  separate, blocked sibling item.
- Not touching `zip.open` itself, its dispatch logic, or its own
  `@overload` annotations — `zip.reader` is purely additive.
