- Does not re-litigate `unix.clock_gettime` (#277) — a different
  function, already settled.
- Does not itself resolve `unix.localtime` — filed as its own sibling
  capture sharing the same implementation and evidence pattern; the
  goal owner may choose to combine both into one PR since both route
  through `LuaUnixTime`, but they are filed separately per this
  item's "each deviation gets its own capture" rule.
