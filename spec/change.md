`third_party/lua/cosmo/lunix.c`, `LuaUnixGetpgrp`: replace the two-branch
header comment with the single `├─→ pgid:int` line, and replace the
`LuaUnixRc0` call with a direct `lua_pushinteger(L, getpgrp()); return 1;`
so the function body matches the annotation #336 landed. No
`definitions.lua` change (already exact). Gate: `make -j$(nproc)
o//tool/lua/test` green; the existing `unix.getpgrp` conformance probe
in `tool/lua/test_definitions_conformance.lua` keeps the observed
one-slot shape pinned.
