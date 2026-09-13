`libc/intrin/gcov.c` (MODE=cov only, `#ifdef MODE_COV` at line 19)
merges the on-disk `.gcda` into live counters and then rewrites the
file with `O_TRUNC`, with no lock between the two. Every enrolled test
runs in parallel under `make -j` and every instrumented process writes
the same `.gcda` per object, so two exiting processes interleave: the
second's read sees a truncated or half-written file, validation fails,
and by design it "proceeds as if the file were fresh", discarding the
first process's counts. Make the merge+write one critical section:

- In `__gcov_write` (`gcov.c:389`), open the path ONCE with
  `O_RDWR | O_CREAT` (no `O_TRUNC`), take a whole-file write lock with
  `__sys_fcntl(fd, F_SETLKW, &(struct flock){.l_type = F_WRLCK,
  .l_whence = SEEK_SET})` (`libc/calls/syscall-sysv.internal.h:17`
  declares `__sys_fcntl`; `libc/sysv/consts/f.h:29` has `F_SETLKW`;
  `libc/calls/struct/flock.h` has the struct), then merge from that fd,
  `ftruncate` to 0, `lseek` to 0, write, and close (closing releases the
  lock). Change `__gcov_merge` to take the fd instead of opening the
  path itself. Keep the raw `sys_*`/`__sys_*` calls: this runs from an
  exit destructor after pledge, and the existing code already avoids
  the libc wrappers for that reason.
- Keep the validate-into-scratch-then-apply discipline; with the lock a
  validation failure now means a foreign or corrupt file, never a
  concurrent writer, so change the header comment (`gcov.c:60-69`)
  that describes the race as tolerated.
- `tool/lua/BUILD.mk:520-523`: the comment "The writer never merges:
  every process that exits rewrites the file whole" is already false
  since #362; rewrite it to say the clean exists so a run's counts are
  only this run's.
- Add `tool/lua/test_gcda_merge.lua`, enrolled ONLY inside the
  `ifeq ($(MODE),cov)` block of `tool/lua/BUILD.mk` (the writer does not
  exist in other modes): fork N=8 children that each `unix.execve` the
  test's own `lua.dbg` (`arg[-1]`) with `-e ""`, wait for all, then
  read `o/cov/tool/net/lfuncs.gcda` (lfuncs.o is instrumented per
  `tool/net/BUILD.mk`) and assert the object-summary `runs` word
  (int32 at byte offset 24: magic, version, stamp, checksum, tag, len,
  runs) equals N plus the value it held before the children ran. Run
  it after `gcda.clean` like every other test so the baseline is 0 or
  the parent's own 1. Before the lock this assertion fails whenever two
  children exit within the same write window; after it, it cannot.
