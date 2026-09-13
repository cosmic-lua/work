One `tool/lua/test_<name>.lua` per source file (a corpus this size does
not fit cosmic's own 500-line file-length convention, and `tool/lua/`
is not bound by it — but one file per source keeps each ported body a
direct, diffable copy of its origin, which is the point of vendoring a
corpus). Each new file opens with the same four-line prelude:

```lua
local cosmo = require("cosmo")
local unix = require("cosmo.unix")
local DecodeJson, EncodeJson, EncodeLua = cosmo.DecodeJson, cosmo.EncodeJson, cosmo.EncodeLua
```

(`unix.pledge(...)` call sites need no rebinding — they already read
`unix.pledge`, and `local unix = require("cosmo.unix")` makes that
resolve.)

| source | destination |
|---|---|
| `test/tool/net/jsonorg_fail_test.lua` | `tool/lua/test_jsonorg_fail.lua` |
| `test/tool/net/jsonorg_pass_test.lua` | `tool/lua/test_jsonorg_pass.lua` |
| `test/tool/net/jsontestsuite_fail1_test.lua` | `tool/lua/test_jsontestsuite_fail1.lua` |
| `test/tool/net/jsontestsuite_fail2_test.lua` | `tool/lua/test_jsontestsuite_fail2.lua` |
| `test/tool/net/jsontestsuite_fail3_test.lua` | `tool/lua/test_jsontestsuite_fail3.lua` |
| `test/tool/net/jsontestsuite_fail4_test.lua` | `tool/lua/test_jsontestsuite_fail4.lua` |
| `test/tool/net/jsontestsuite_okay_test.lua` | `tool/lua/test_jsontestsuite_okay.lua` |
| `test/tool/net/jsontestsuite_pass_test.lua` | `tool/lua/test_jsontestsuite_pass.lua` |
| `test/tool/net/ljson_test.lua` | `tool/lua/test_ljson.lua` |

Each gets its own three-line `tool/lua/BUILD.mk` rule, following the
existing shape at `tool/lua/BUILD.mk:222-251` exactly (e.g. for the
first):

```make
o/$(MODE)/tool/lua/test_jsonorg_fail.ok: o/$(MODE)/tool/lua/lua.dbg tool/lua/test_jsonorg_fail.lua
	$< tool/lua/test_jsonorg_fail.lua
	@touch $@
```

...and one new line per file added to the `TOOL_LUA_TESTS` list
(`tool/lua/BUILD.mk:222-251`), e.g.:

```make
	o/$(MODE)/tool/lua/test_jsonorg_fail.ok				\
```

No other file changes. `ljson_test.lua`'s `i_structure_500_nested_arrays`
case comment says spaces were added between `[[` and `]]` "so lua
doesn't get confused" — preserve that when copying the body; it is not
an artifact to clean up.
