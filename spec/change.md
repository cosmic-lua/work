1. **`cosmic/quicksand/init.tl`** (measured: `capabilities()` at ~147
   already computes `has_landlock` via the shared probe, PR #1278):
   capabilities gain `landlock_net: boolean` — true when the probed ABI
   is ≥ 4 (read from `cosmic.sandbox.landlock`, the one cached probe).
2. **Box setup**: when a Box's network policy is requested and
   `net_ns` is unavailable but `landlock_net` is true, apply the
   sandbox `net` section in the child after fork — defense in depth:
   when the netns IS available, both apply (the netns for isolation,
   the port tier as backstop). The Box's report/why-degraded surface
   states which tier is in effect, using the same full/degraded/skipped
   vocabulary the R1 report standardized.
3. **Tests**: a Box on a netns-less, ABI-4 host confines connect to the
   allowed ports (CI ubuntu exercises it); the capability flag pins in
   the existing capabilities test.
