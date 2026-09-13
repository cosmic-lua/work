1. `build/config.mk`: a `MODE=cov` block modelled on `dbg`
   (ENABLE_FTRACE=1, -O0, `-DMODE_COV`), NOT adding the coverage flags
   globally.
2. `tool/net/BUILD.mk`, `tool/lua/BUILD.mk`, `third_party/lua/BUILD.mk`:
   `ifeq ($(MODE),cov)` per-object `private CFLAGS += -fprofile-arcs
   -ftest-coverage -dumpdir $(@D)/ -dumpbase $(@F)` on exactly the
   binding objects (the TOOL_LUA_LUA_MODULES list plus lfuncs.o and
   lunix.o), same `private` shape as `o/$(MODE)/tool/net/lsqlite3.o:`
   at tool/net/BUILD.mk:122. First verify tlscc forwards `-dumpdir`/
   `-dumpbase` untouched (it copies args and rewrites only `-c`/`-o`;
   measured so far only on the gcc line it emits); if it does not,
   teach tlscc to append them from its own `output` when it sees
   `-ftest-coverage`. Expected result per object: `o/cov/<path>/<stem>.o.gcno`
   and an embedded `o/cov/<path>/<stem>.o.gcda` (absolute).
3. A real runtime, `libc/intrin/gcov.c`, compiled only when
   `MODE_COV` is defined and replacing the weak stubs: `__gcov_init`
   chains each `struct gcov_info` onto a list; `__gcov_exit` writes
   `info->filename` in the format of GCC 14.1's `gcc/gcov-io.h` /
   `libgcc/libgcov.h` — READ those headers from the 14.1 source for
   the record encoding (magic `gcda`, version = info->version, stamp,
   checksum, then per function a GCOV_TAG_FUNCTION record and one
   GCOV_TAG_FOR_COUNTER(i) record per non-empty counter set; verify
   the length unit in gcov-io.h). No merge with an existing file: the
   test rule deletes `o/cov/**/*.gcda` before the run.
   `__gcov_merge_add` and the fork/exec hooks stay no-ops.
4. Reader: the host `gcov` (13.3 or newer), run from the object
   directory with `-o`: `gcov -o o/cov/tool/net o/cov/tool/net/lsqlite3.o.gcno`
   (expect the `prefer 'B33*'` warning; treat it as noise). Not
   `llvm-cov gcov`, not a hand-written reader.
5. `make MODE=cov o/cov/tool/lua/test`, then step 4 on
   `tool/net/lsqlite3.c` — record the lines-executed percentage in the
   PR; measure once per binding file.
