- Not a claim that the lock itself (`F_SETLKW` in `__gcov_write`) is
  broken — every measurement above confirms it works; this item is
  about the TEST's power to detect its absence, not the lock's
  correctness.
- Not a change to `.github/workflows/pr.yml` or any other CI wiring —
  purely internal to how `test_gcda_merge.lua` measures itself.
- Not a general audit of other probabilistic tests in this repo; scoped
  to this one test, found via this one item's review cycle.
