Three new files, each with the same one-line prelude:

```lua
local unix = require("cosmo.unix")
```

| source | destination |
|---|---|
| `test/tool/net/setenv_test.lua` | `tool/lua/test_unix_setenv.lua` |
| `test/tool/net/unsetenv_test.lua` | `tool/lua/test_unix_unsetenv.lua` |
| `test/tool/net/clearenv_test.lua` | `tool/lua/test_unix_clearenv.lua` |

`tool/lua/BUILD.mk:222-251` gets three new three-line rules
(`o/$(MODE)/tool/lua/test_unix_setenv.ok: o/$(MODE)/tool/lua/lua.dbg
tool/lua/test_unix_setenv.lua`, run, `@touch $@`, and the same shape for
the other two), and three new `TOOL_LUA_TESTS` lines.

`clearenv_test.lua` wipes the WHOLE process environment
(`unix.clearenv()`), which — if the test runner shares a process with
later stamps or reuses environment state the runner itself depends on
(`TMPDIR`, `PATH`) — could affect what runs after it in the same
`make` invocation. Confirm each `tool/lua/test_*.ok` rule invokes a
fresh `o/$(MODE)/tool/lua/lua.dbg` process (it does, per the existing
rule shape: `$< tool/lua/test_<name>.lua` is one process per stamp), so
this is inert; note it in the ported file's header comment rather than
silently relying on process isolation nobody wrote down.
