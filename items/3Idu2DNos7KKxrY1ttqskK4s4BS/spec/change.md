| source | destination | prelude |
|---|---|---|
| `test/tool/net/path_test.lua` | `tool/lua/test_path_values.lua` | `local cosmo = require("cosmo")` / `local unix = require("cosmo.unix")` / `local path = require("cosmo.path")` |
| `test/tool/net/readlink_test.lua` | `tool/lua/test_unix_readlink.lua` | none — already requires what it needs |
| `test/tool/net/slurp_test.lua` | `tool/lua/test_slurp_ranges.lua` | `local cosmo = require("cosmo")` / `local unix = require("cosmo.unix")` / `local Slurp, Barf = cosmo.Slurp, cosmo.Barf` |

`slurp_test.lua`'s single positional `Barf(...)` call (line 34 of the
source) becomes `Barf(Path('foo'), 'XX', {offset = 3})` in the ported
file; every other line moves unchanged.

`path_test.lua`'s two `assert(nil == path.join(nil[, nil]))` lines
become:

```lua
assert(not pcall(path.join, nil), "join(nil) must raise")
assert(not pcall(path.join, nil, nil), "join(nil, nil) must raise")
```

every other assertion in the file (all `dirname`/`basename` cases,
every other `join` case including the long-string stress case and the
numeric-coercion case) moves unchanged.

`tool/lua/BUILD.mk:222-251` gets three new three-line rules
(`o/$(MODE)/tool/lua/test_path_values.ok: o/$(MODE)/tool/lua/lua.dbg
tool/lua/test_path_values.lua`, run, `@touch $@`, and the equivalent
for `test_unix_readlink` and `test_slurp_ranges`), and three new
`TOOL_LUA_TESTS` lines.
