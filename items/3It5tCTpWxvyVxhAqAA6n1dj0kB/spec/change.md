1. `gitgraph.tl`, `gitcompare.tl`'s pre-write checks, `gitfsck.tl`,
   `health.tl`: no change.
2. `gitcompare.tl:104` only: replace `store.list(s)` with `cache.open(s.
   root)` + `cachequery.items(c)` (from «VkzD_q8u2», which this item is
   `blocked_by`), keeping `prio.key_of(prio.positions(...), winner)`
   exactly as written today over the result. The cache is current at that
   point because the write just patched it (`cache.after_save`).
3. Test: the existing `_work/gitcompare_test.tl` cases pass unchanged (the
   printed band/own line is byte-identical); add one case asserting the
   post-write report calls `store.list` zero times (module-table counting
   stub, the pattern #18 introduced).
