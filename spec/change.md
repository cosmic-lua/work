One PR on cosmic-lua/cosmopolitan: give `lua.main.o` real edges —
either compile it at the path `mkdeps` derives (`o/$(MODE)/third_party/
lua/cosmo/lua.main.o`, with the `-DLUA_COSMO` flag as a `private
CFLAGS` on that object) and link that, or add an explicit
`o/$(MODE)/tool/lua/lua.main.o: $(o/$(MODE)/third_party/lua/cosmo/
lua.main.o's edge sources)` alias in `tool/lua/BUILD.mk`. Prefer the
first: one object, one path, `depend` carries it. Extend the
`test_srcs_scan.lua` gate from #355 to also assert that every object
`tool/lua/lua` links has a `depend` block, failing by object path.
