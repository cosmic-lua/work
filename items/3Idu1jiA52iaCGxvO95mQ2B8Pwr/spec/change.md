One new file, `tool/lua/test_fetchstream_edge.lua`, copied from
`test/tool/net/lfetchstream_test.lua` verbatim (its self-prelude
already resolves under `require("cosmo")`/`require("cosmo.unix")`
being available — no additional aliasing needed beyond what the file
already does).

`tool/lua/BUILD.mk:222-251` gets one new three-line rule
(`o/$(MODE)/tool/lua/test_fetchstream_edge.ok: o/$(MODE)/tool/lua/lua.dbg
tool/lua/test_fetchstream_edge.lua`, run, `@touch $@`) and one new
`TOOL_LUA_TESTS` line.
