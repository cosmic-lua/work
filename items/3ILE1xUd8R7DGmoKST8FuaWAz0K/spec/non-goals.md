- **Do not restore the removed upstream design.** No `freelist` member
  on `struct Zipos`, no first-fit `mapsize >=` scan, no `StartOver`
  retry, no `__zipos_lock`/`pthread_mutex_t`, and no return of
  `__zipos_mmap_space`/`kMemtrackZiposStart`. Those are what
  `464858db` removed and the reasons are recorded in `3IKuRFN5`.
- **Do not recycle the other two allocation sites.** `:116`
  (synthetic directory, `size + 1`) and `:132` (deflate, full
  uncompressed size) stay on plain `mmap`/`munmap`. Size-bucketing
  them would retain megabyte mappings for the process lifetime to
  speed up opens whose cost is `__inflate`, not `mmap`.
- **Do not raise `ZIPOS_FREE_SLOTS` above 4 in this slice**, and do
  not add reclamation policy, a timer, or high-water logic. The cap is
  structural. Raising it needs a measurement of concurrent depth,
  which is a separate item.
- **Do not touch the other four syscalls in the pair.** `fcntl`,
  `close` and `__zipos_open`'s own two `rt_sigprocmask` are out of
  scope; this slice is the `mmap`/`munmap` pair and the four
  sigprocmasks nested in them.
- **Do not change the binding contract.** No `cosmo.*` return shape,
  error value or constant moves, so no `tool/net/definitions.lua`
  update and no cosmic-side type regen belongs in this PR.
- **Do not modify existing testlib assets or existing tests.** The
  stored asset is a new file whose only consumer is the new
  `TEST(zipos, storedRecycleConcurrent)`; do not switch `hyperion`
  or any other shared asset to stored, and do not extend
  `TEST(zipos, test)`'s Worker to open the new asset — the two tests
  cover the two paths separately so a failure names its own primitive.
