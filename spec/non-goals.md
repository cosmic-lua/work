- No change to `own`, to the transitive closure, or to how `uncompare`
  works — the recovery path is correct today and is what makes this
  safe to work on.
- No change to `placed` or to the `check` gate that refuses to promote
  unplaced work. The comment at `priority.tl:269-271` explains why
  `placed` is deliberately not lifted; leave it.
- Not a re-ranking of any item. This is the mechanism, not the order.
