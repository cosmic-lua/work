- **No strict mode.** This slice does not make any sink refuse a nil
  union. `test_nil_union_is_admitted_outside_an_index` must still pass
  unchanged — the four positions it pins still admit a union after this
  lands, because none of its five sinks carries a guard.
- **Do not bump the `tl` pin.** 0.24.8; the anchors are matched against
  it.
- **Do not fix a census site.** Every site this removes, it removes by
  the checker learning something, never by an edit at the site. A diff
  that touches `cosmic/fs/tree.tl` or `_tool/testrun_test.tl` is out of
  scope.
- **Do not open the upstream PRs here.** Land the carried patch first;
  proposing them to teal-language/tl is separate work with its own
  review.
- **Do not rewrite `docs/design/nil-flow.md`'s totals.** It is dated
  against `e7ac1580`; a later census re-derives it.
