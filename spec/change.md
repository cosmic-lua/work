Two new files, each with the same one-line prelude:

```lua
local unix = require("cosmo.unix")
```

| source | destination |
|---|---|
| `test/tool/net/execvp_test.lua` | `tool/lua/test_unix_execvp.lua` |
| `test/tool/net/daemon_test.lua` | `tool/lua/test_unix_daemon.lua` |

`tool/lua/BUILD.mk:222-251` gets two new three-line rules
(`o/$(MODE)/tool/lua/test_unix_execvp.ok: o/$(MODE)/tool/lua/lua.dbg
tool/lua/test_unix_execvp.lua`, run, `@touch $@`, and the equivalent for
`test_unix_daemon`), and two new `TOOL_LUA_TESTS` lines.

`daemon_test.lua`'s marker-file wait (`unix.nanosleep(0, 200000000)`,
200ms) is a real, if generous, timing assumption already present in the
source; carry it as-is — the file already treats a missing marker as a
printed warning rather than a hard failure, so it is not flaky by
construction, just slow-by-a-fifth-of-a-second in the worst case.
