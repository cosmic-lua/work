- Phase 1 defect 2 (`REFER` handled but never granted): out of scope,
  and on inspection appears **already fixed** in the current tree —
  `WRITE` (`cosmic/sandbox/landlock.tl` line 76) already ORs in
  `REFER`, and `landlock_test.tl` already has a passing
  `test_rw_grant_allows_rename_within_its_tree` (line 217) covering
  cross-directory rename inside one `rw` grant. Do not re-touch the
  `WRITE`/`RW`/`ALL` mask constants (lines 73–78) in this slice.
- Phase 1 defect 3 (`fs.optional` TOCTOU pre-check in
  `cosmic/sandbox/init.tl`'s `present_only`/`effective_fs`): untouched.
  Do not change `cosmic/sandbox/init.tl` at all in this slice.
- Phase 1 defect 4 (silent ABI downgrade reported as full enforcement;
  truthy `{fs=false,sys=false}` under `best_effort`): untouched. Do
  not change `Availability`, `apply`'s return shape, or add a
  `strict` option in this slice.
- No "handled field decision" (whether `handled` should be removed
  from `sandbox.Options` per R3's "on the table" note) — this slice
  makes the existing field behave correctly, it does not decide
  whether the field should exist.
- No change to `abi_mask`, `FILE_BITS`, or any other constant in
  `cosmic/sandbox/landlock.tl` besides the one line named above.
- No change to `cosmic/sandbox/plan.tl` — it never sets `opts.handled`
  narrower than default today, so it needs no change for this fix to
  take effect the moment a caller (present or future) does narrow it.
- Phase 2 (the C-layer kernel ceiling: `libc/calls/landlock.h`,
  `lunix.c`, ABI 4–9 bindings in whilp/cosmopolitan) and Phase 3 (the
  `net` section, quicksand consuming it, TSYNC, docs) are untouched —
  this slice makes no C/kernel-binding change of any kind.
