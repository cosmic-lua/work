- No change to `unix.sigaction` or `unix.setitimer` — the sibling
  class-2 tuple-deviation captures, filed separately
  (`3IjRZi3mc1TW31yGcE7e615d4Lc`, `3IjRa88PfMHXoRab5q1vZjeIuTa`).
- No change to `unix.sigset`/`unix.Sigset` construction or the
  `newmask` argument check (`luaL_checkudata`) — already a type-shape
  error, unrelated to this fix.
- No cosmic-side edit and no cosmos pin bump — the sibling consumption
  slice, blocked on this one landing.
