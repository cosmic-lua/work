- **Do not change what any of the three functions DOES.** The semantics
  frozen in the module header (`cosmic/deep.tl:15-23`) all stay exactly
  as they are: copy copies table keys as well as values, shared
  references stay shared within one copy, cycles terminate, metatables
  are not copied, `equal` matches table-valued keys by identity rather
  than structure, and `merge` recurses only where both sides hold tables
  so lists merge by index. This slice moves types, not behaviour.
- **Do not touch `equal`.** Its `(a: any, b: any): boolean` signature
  costs no caller a cast, and its five out-of-file callers are the
  `_fuzz` tests, which this slice must leave untouched.
- **Do not change `copy_impl`, `eq_impl` or `merge_impl`.** The dynamic
  walk is the implementation and stays `any`-typed; the generics are a
  boundary over it, which is what the two casts are.
- **Do not weaken or delete a test assertion, or an example's
  `-- Output:` block.** Casts and fixture annotations change; asserts and
  printed output do not.
- **Do not edit `docs/design/casts.md`.** It is a dated snapshot
  ("Measured against `d3e59de7` on 2026-08-25"), not a live table, and
  `3IOmgCA2` set the precedent of leaving it alone; refreshing one
  bucket's rows would leave the document half-current.
- **No new `-- cast: from any` anywhere.** The only casts this diff adds
  are the two in `cosmic/deep.tl`, with the reasons named above.
- **Do not touch any other file.** The diff is three sources plus the
  regenerated `_build/casts_baseline.tl`.
