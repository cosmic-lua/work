- No change to `LuaUnixGmtime`/`LuaUnixLocaltime` themselves (lines
  2855-2864) — both are one-line forwarders to `LuaUnixTime` already
  and need no edit.
- No addition to the pure-function `PROBES` ratchet in
  `tool/lua/test_definitions_conformance.lua` — `localtime` reads the
  `TZ` environment variable and the on-disk zoneinfo database, so
  neither binding is the "zero-risk... no side effects" set that file
  scopes itself to.
- **Cosmic-side edit required, but not by this capture.** This is a
  BEHAVIOR change for BOTH bindings: `cosmic/time.tl:127-132`
  (`gmtime`) and `:157-162` (`localtime`) both break the moment this
  lands. Retiring both destructurings for `.year`/`.mon`/... field
  access is the sibling consumption slice, BLOCKED on this capture
  landing — do not fold it into this diff, and do not bump the cosmos
  pin here.
- `localtime`'s OWN test coverage (it has none today) is the sibling
  capture `3IjRasyoYAsJxkJsQIBK9EPn3GK`, not this one — this capture's
  `tool/lua/test_unix_misc.lua` work touches only the existing
  `gmtime` block.
