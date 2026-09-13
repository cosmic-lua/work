- No change to `LuaUnixOpenpty`'s C implementation or its return
  arity — the 3-success/3-failure shape stays; only the annotation
  changes.
- No change to any other binding, including `unix.pipe` and
  `unix.tiocgwinsz`, which have the identical pattern and independent
  sibling captures.
- No change to `cosmic/tty.tl`'s `open_pty` — it already handles the
  real shape correctly; nothing there is broken by this doc fix.
