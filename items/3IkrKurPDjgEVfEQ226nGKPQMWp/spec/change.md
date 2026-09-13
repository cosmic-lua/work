`third_party/lua/cosmo/lunix.c`, `LuaUnixIsatty`: delete the
unreachable `rc == -1` branch and the `olderr` it exists for, leaving
`lua_pushboolean(L, isatty(fd))`-shaped code with exactly one return
path. Comment lines above it stay as #347 left them (`└─→ bool`). No
`definitions.lua` change, no `help.txt` change: the contract does not
move. `make -j$(nproc) o//tool/lua/test` green; if a test asserts the
old failure tuple from isatty, that test is asserting a path the
binding never took and is fixed to assert `false` — name it in the PR.
