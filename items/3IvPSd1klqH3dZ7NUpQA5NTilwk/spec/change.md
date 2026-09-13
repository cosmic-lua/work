`tool/lua/BUILD.mk`, immediately above the `TOOL_LUA_LUA_MODULES =`
definition (line 36) add:

```
# lfuncs3.o compiles the same source as tool/net/lfuncs.c (see
# tool/lua/lfuncs3.c: `#define USE_MBEDTLS3` then `#include
# "tool/net/lfuncs.c"`) under a different macro — it is the one
# lfuncs.c object actually linked into lua.dbg, so under MODE=cov its
# .gcda (not tool/net/lfuncs.o's) is the one that reflects this test
# target's coverage of lfuncs.c.
```

`tool/net/BUILD.mk:126-127`, replace the existing comment (currently
"lfuncs.o is the one binding object outside TOOL_LUA_LUA_MODULES; see
the MODE=cov block in tool/lua/BUILD.mk.") with:

```
# lfuncs.o is the one binding object outside TOOL_LUA_LUA_MODULES —
# tool/lua/BUILD.mk's TOOL_LUA_LUA_MODULES instruments lfuncs3.o
# instead, a separate object compiled from this same source (see the
# comment there). This object (lfuncs.o) is redbean's, never linked
# into the test binary; its own .gcda under MODE=cov carries no test
# coverage.
ifeq ($(MODE),cov)
o/$(MODE)/tool/net/lfuncs.o: private					\
		CFLAGS +=						\
			$(COVERAGE_CFLAGS)
endif
```

No other files change. This is a comment-only edit — no rule, target,
or object list changes — so `make -j$(nproc) o//tool/lua/test` is
unaffected; run it once after editing to confirm the build still
succeeds unchanged.
