- No change to the existing `sig` range check (lines 2667-2671) — that
  failure already raises and is out of this capture's scope.
- No addition to the pure-function `PROBES` ratchet in
  `tool/lua/test_definitions_conformance.lua` — `sigaction` installs a
  real signal disposition, so it is not the "zero-risk... no side
  effects" binding that file scopes itself to.
- **Cosmic-side edit required, but not by this capture.** This is a
  BEHAVIOR change, unlike the honest-annotation-only fix this capture
  previously proposed: `cosmic/signal.tl:251-252`'s
  `local prev, prev_flags, prev_mask = unix.sigaction(...)` breaks the
  moment this lands (`prev_flags`/`prev_mask` go from real values to
  always-nil). Retiring that destructuring for `result.handler` /
  `result.flags` / `result.mask` is the sibling consumption slice,
  BLOCKED on this capture landing — do not fold it into this diff, and
  do not bump the cosmos pin here.
