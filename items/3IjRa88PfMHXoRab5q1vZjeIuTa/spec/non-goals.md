- No addition to the pure-function `PROBES` ratchet in
  `tool/lua/test_definitions_conformance.lua` — `setitimer` arms a
  real interval timer, so it is not the "zero-risk... no side
  effects" binding that file scopes itself to.
- **Cosmic-side edit required, but not by this capture.** This is a
  BEHAVIOR change: `cosmic/signal.tl:201`'s `local old_isec, old_ins,
  old_vsec, old_vns = unix.setitimer(...)` breaks the moment this
  lands. Retiring that destructuring for `previous.intervalsec` /
  `.intervalns` / `.valuesec` / `.valuens` is the sibling consumption
  slice, BLOCKED on this capture landing — do not fold it into this
  diff, and do not bump the cosmos pin here.
