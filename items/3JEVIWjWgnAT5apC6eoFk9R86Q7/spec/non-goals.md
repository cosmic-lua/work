- No change to `IsBase64` (`net/http/isbase64.c`) — its own alignment
  fix (#281) already landed and is out of scope here.
- No revisit of the `.balign 64` layout directives already in
  `decodebase64.c`/`isbase64.c` — those stay; this is an additive
  algorithmic change layered on top of the existing (correctly aligned)
  loop.
- No change to the tolerant-skip contract, the dual-alphabet support,
  or any `cosmo.*` return shape — `definitions.lua` is read for
  confirmation, not edited for substance.
- No SIMD/vector intrinsics — the four-table scalar approach is the
  smallest change that removes the per-character branch; a
  vectorized version is a separate, larger idea if this is insufficient.
- No touching `net/http/ssh.c`, `tool/net/lfuncs.c`, or
  `tool/lua/lcosmo.c` — the C↔Lua wiring (`LuaCoder`/`LuaEncodeBase64`/
  `LuaDecodeBase64`, `tool/net/lfuncs.c:946-951`) is unaffected by an
  internal loop rewrite.
