One new file, `tool/lua/test_unix_misc.lua`, from
`test/tool/net/lunix_test.lua`, with:

```lua
local unix = require("cosmo.unix")
```

...and the `sigsuspend` interruption check rewritten from
`assert(err:errno() == unix.EINTR)` to read the errno positionally
from `unix.sigsuspend`'s own third return value, per the fork's
`nil, err:string, errno:integer` failure contract (see Evidence).
Every other line — `strsignal`, `gmtime`, `dup`/`dup2`, the
`fork`+`wait`+exit-code check, the `pledge` violation-and-kill child,
the ranged file-I/O block, `copy_file_range` and its `ENOSYS`
fallback branch, and the `opendir`/getdents listing — moves unchanged.

`tool/lua/BUILD.mk:222-251` gets one new three-line rule
(`o/$(MODE)/tool/lua/test_unix_misc.ok: o/$(MODE)/tool/lua/lua.dbg
tool/lua/test_unix_misc.lua`, run, `@touch $@`) and one new
`TOOL_LUA_TESTS` line.
