One new file, `tool/lua/test_sqlite_readonly.lua`, from
`test/tool/net/sqlite_test.lua`, with its one `require` line changed:

```lua
local sqlite3 = require("cosmo.lsqlite3")
```

(replacing the source's `local sqlite3 = require "lsqlite3"` — every
other line, including the `file:/memdb1?vfs=memdb` URI-mode opens and
the `db:exec`/`db:prepare` calls, moves unchanged).

`tool/lua/BUILD.mk:222-251` gets one new three-line rule
(`o/$(MODE)/tool/lua/test_sqlite_readonly.ok: o/$(MODE)/tool/lua/lua.dbg
tool/lua/test_sqlite_readonly.lua`, run, `@touch $@`) and one new
`TOOL_LUA_TESTS` line.
