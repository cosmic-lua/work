Two new files, each with the same two-line prelude:

```lua
local cosmo = require("cosmo")
local unix = require("cosmo.unix")
local EncodeJson, EncodeLua = cosmo.EncodeJson, cosmo.EncodeLua
```

| source | destination |
|---|---|
| `test/tool/net/encodejson_test.lua` | `tool/lua/test_encodejson_default.lua` |
| `test/tool/net/encodelua_test.lua` | `tool/lua/test_encodelua_default.lua` |

Both source files end in a `-- benchmark` comment block plus
`JsonEnc*`/`LuaEnc*`/`bench()` functions used only by the old redbean
benchmark harness (`Benchmark(...)`, which this fork does not carry
under `cosmo.*`) — drop that trailing block from both ported files; it
is dead weight, not assertions, and `Benchmark` has no `cosmo.*`
equivalent to alias it to.

`tool/lua/BUILD.mk:222-251` gets two new three-line rules, e.g.:

```make
o/$(MODE)/tool/lua/test_encodejson_default.ok: o/$(MODE)/tool/lua/lua.dbg tool/lua/test_encodejson_default.lua
	$< tool/lua/test_encodejson_default.lua
	@touch $@
```

...and two new `TOOL_LUA_TESTS` lines.
