Three new files, each with the same one-line prelude:

```lua
local unix = require("cosmo.unix")
```

| source | destination |
|---|---|
| `test/tool/net/getlogin_test.lua` | `tool/lua/test_unix_getlogin.lua` |
| `test/tool/net/uname_test.lua` | `tool/lua/test_unix_uname.lua` |
| `test/tool/net/tcattr_test.lua` | `tool/lua/test_unix_tcattr.lua` |

`tool/lua/BUILD.mk:222-251` gets three new three-line rules (same shape
as the existing entries: `o/$(MODE)/tool/lua/test_unix_getlogin.ok:
o/$(MODE)/tool/lua/lua.dbg tool/lua/test_unix_getlogin.lua`, run,
`@touch $@`, and the equivalent for `test_unix_uname` and
`test_unix_tcattr`), and three new `TOOL_LUA_TESTS` lines.

`tcattr_test.lua`'s pty-dependent block is already conditional on
`unix.open("/dev/ptmx", ...)` succeeding, with a printed skip note
otherwise — carry that structure verbatim; do not make the pty
assertions unconditional, since a CI runner without a pty device must
still pass.
