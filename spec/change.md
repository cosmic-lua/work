In `cosmic/sandbox/init.tl`'s `merge()`, add a `scope` branch alongside
the (now-fixed) `net` branch and the existing `fs`/`sys` branches. Per
item `3IhTfAF5`'s landed fix (PR #1602) for the precedent shape: follow
the same pattern used there for `net` — `Scope`'s fields (`signal:
boolean`, `abstract_unix: boolean`, per `3I7LKuM2`'s landed shape) are
booleans, not lists, so this likely wants OR-composition (either policy
requesting `true` makes the merged result `true`) rather than the
concat-and-dedupe shape `merged_list`/`merged_int_list` use for list
fields — verify the exact composition semantics against `apply()`'s
actual use of `Scope` before choosing.

Extend `cosmic/sandbox/init_test.tl`'s `test_merge_composes_policies`
with `scope` coverage, mirroring the pattern the `net` fix (PR #1602)
used for its own coverage.
