One file, one added line: `tool/net/lfuncs.c` (1316 lines today; this
repo has no per-file cap, so headroom is not the question — surgical
diff size is, per AGENTS.md).

Add exactly this line, and nothing else:

```c
#include "libc/sysv/consts/clock.h"
```

Its position is line 54, between `#include "libc/sysv/consts/af.h"`
(`:53` today) and `#include "libc/sysv/consts/ipproto.h"` (`:54` today).
That keeps the file's existing alphabetical ordering inside the
`libc/sysv/consts/` group, which is how `redbean.c`, `stampd.c` and
`drift.c` order theirs.

No other edit. `LuaResolveIpTimeout`'s body does not change, no existing
include moves, and no `#ifdef` is touched.
