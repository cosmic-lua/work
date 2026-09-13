- **No cast-site removal in this PR**, including the 3 sites the new
  rule would actually let through
  (`_fuzz/compress_fuzz_test.tl:76`, `cosmic/compress_test.tl:24`,
  `cosmic/compress_test.tl:36`). `_build/coldbuild_test.tl` type-checks
  the whole tree with `o/bootstrap/cosmic` — the CURRENT
  `bin/cosmic.pin`, which does not carry this patch — so any tree
  source that needs the new rule to check fails that test locally, not
  just in CI's cold lanes. Land the patch alone first; removing those
  3 casts (and rebaselining `_build/casts_baseline.tl`) is a follow-up
  item, pulled only after `bin/cosmic.pin` bumps to a release built
  with this patch.
- **No "enum is a subtype of `string`" patch entry.** That relation
  already exists in tl 0.24.8 (`subtype_relations["enum"]["string"] =
  compare_true`); adding it again is a no-op at best.
- **No attempt at the other 8 enum-relation sites**
  (`cosmic/compress_test.tl:139`; `cosmic/hash.tl:104,141,203`;
  `cosmic/sys.tl:46`; `cosmic/sys_test.tl:14,29`;
  `cosmic/fetch/init.tl:214`). Each casts a plain `string` — an
  untyped binding return, a `string.upper()` result, or a
  guard-narrowed value — INTO a narrower enum, the reverse direction
  from this item's rule, and needs guard-based literal narrowing (or,
  for the binding-boundary sites, may not be soundly closeable by a
  checker rule at all). That is separate, harder work for a future
  item, not a size cut of this one.
- **No upstream tl PR.** This session's write access does not reach
  `teal-language/tl`; the carried patch is the only route available
  here, per the Goal's own routing.
