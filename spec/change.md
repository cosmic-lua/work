In cosmic-lua/cosmopolitan:

1. Delete the directory `test/tool/net/` entirely — all 40 test files,
   `redbean_test.c`, `sqlite_test.c`, and its `BUILD.mk`.
2. Delete line 9 of `test/tool/BUILD.mk`, the
   `o/$(MODE)/test/tool/net` entry in the `o/$(MODE)/test/tool`
   prerequisite list. Leave the other four entries (`args`, `build`,
   `plinko`, `viz`) and the trailing-backslash continuation of the
   line above it correct — the list is tab-indented and
   backslash-continued, so removing the last-but-one entry means
   fixing the continuation on whichever line becomes last.
3. Delete line 399 of the root `Makefile`, `include
   test/tool/net/BUILD.mk` — otherwise `make` errors on every target
   once the included file no longer exists.

Nothing else. This is a deletion, not a refactor.
