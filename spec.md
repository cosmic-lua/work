## Goal

`tool/net/lfuncs.c` compiles into two different objects under
`MODE=cov`, and only one comment names the split — the other side is
silent, so reading either `BUILD.mk` alone gives the wrong answer
about which object's `.gcda` reflects real test coverage.

## Evidence

`tool/net/BUILD.mk:126-127`:

```
# lfuncs.o is the one binding object outside TOOL_LUA_LUA_MODULES; see
# the MODE=cov block in tool/lua/BUILD.mk.
ifeq ($(MODE),cov)
o/$(MODE)/tool/net/lfuncs.o: private					\
		CFLAGS +=						\
			$(COVERAGE_CFLAGS)
endif
```

This instruments `tool/net/lfuncs.o` (compiled directly from
`tool/net/lfuncs.c`) for `redbean`/`redbean-demo`
(`TOOL_NET_REDBEAN_LUA_MODULES`, same file, line 99) — but that object
is never linked into `o/$(MODE)/tool/lua/lua.dbg`, the binary
`make MODE=cov o/cov/tool/lua/test` builds and runs.

`tool/lua/BUILD.mk:36-38` (`TOOL_LUA_LUA_MODULES`, the list the `cov`
block at line 512 instruments and the test binary links):

```
TOOL_LUA_LUA_MODULES =							\
	o/$(MODE)/tool/lua/lcosmo.o					\
	o/$(MODE)/tool/lua/lfuncs3.o					\
	o/$(MODE)/tool/net/lpath.o					\
	...
```

`tool/lua/lfuncs3.c` (its only content, `cat tool/lua/lfuncs3.c`):

```
#define USE_MBEDTLS3
#include "tool/net/lfuncs.c"
```

So `lfuncs3.o` compiles the SAME source (`tool/net/lfuncs.c`) as
`lfuncs.o`, under a different macro, and is the one actually linked
into the test binary — confirmed by `grep -n lfuncs tool/net/BUILD.mk
tool/lua/BUILD.mk`, which shows `lfuncs.o` appearing only in
`TOOL_NET_REDBEAN_LUA_MODULES` (net/BUILD.mk:99) and its own `cov`
override (net/BUILD.mk:129), while `lfuncs3.o` appears only in
`TOOL_LUA_LUA_MODULES` (lua/BUILD.mk:38). Neither `BUILD.mk` states
this at the `lfuncs3.o`/`TOOL_LUA_LUA_MODULES` side: `tool/lua/BUILD.mk`'s
own `MODE=cov` comment block (lines 506-511, added by
cosmic-lua/cosmopolitan#359) explains the instrumentation and dump
mechanism in general but never mentions `lfuncs3.o`'s split from
`lfuncs.o` at all. A reader auditing `tool/lua`'s `cov` coverage from
that file alone has no way to know `lfuncs.o`'s `.gcda` (if it exists
under this build at all) is not the one to read for `lfuncs.c`'s test
coverage — this was independently re-derived, cross-referencing three
`BUILD.mk` files, while sizing board item `W3uo_Bvcn` (gcov per-file
line-coverage floor, cosmic-lua/cosmopolitan, parent outcome
`0isr_qZds`), which now documents the same finding in its own Evidence
section as a `## Change` prerequisite fact.

## Change

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

## Non-goals

- Does not change which object `MODE=cov` instruments or links, or
  add any actual coverage measurement — that is board item `W3uo_Bvcn`
  (gcov per-file line-coverage floor), which depends on a reader (or a
  future line-coverage script) already knowing this split; this item
  only makes that fact readable from either `BUILD.mk` file alone.
