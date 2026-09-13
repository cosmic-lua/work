One new file, `tool/lua/test_lua_extensions.lua`, from
`test/tool/net/lua_test.lua`, with:

```lua
local unix = require("cosmo.unix")
```

...and the `ProgramContentType` block (source lines 25-32: the
`assert(ProgramContentType(...) == ...)` calls and the
`ProgramContentType("1", "text/x-foo")` registration) DROPPED. Every
other assertion (`0b100`, `0200`, `"\e"`, `"hi" * 3`,
`"hello %d" % {123}`) moves unchanged.

`tool/lua/BUILD.mk:222-251` gets one new three-line rule
(`o/$(MODE)/tool/lua/test_lua_extensions.ok: o/$(MODE)/tool/lua/lua.dbg
tool/lua/test_lua_extensions.lua`, run, `@touch $@`) and one new
`TOOL_LUA_TESTS` line.
