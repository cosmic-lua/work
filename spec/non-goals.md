- No change to `LuaUnixTiocgwinsz`'s C implementation or its return
  arity — the 2-success/3-failure shape stays; only the annotation
  changes.
- No change to any other binding, including `unix.pipe` and
  `unix.openpty`, which have the identical pattern and independent
  sibling captures.
- No change to `cosmic/tty.tl`'s `window_size` — it already handles the
  real shape correctly (modulo discarding the errno, which is a
  cosmic-side follow-up outside this capture's scope, not this one).
