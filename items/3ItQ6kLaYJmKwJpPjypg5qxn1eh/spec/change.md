Decide, then respec `3Int8VXj`'s `## Change` accordingly:

1. Either (a) scope this item's UDF-argument bullet out entirely — ship
   only the `column_type`-based read-side wrap and the `bind_at`
   round-trip dispatch on the existing write-side `Blob`/`blob()` marker
   (already present, `cosmic/sqlite/bind.tl`, re-exported at
   `cosmic/sqlite/init.tl:427,439,453`) — and open a separate, later item
   for UDF registration support if `cosmic.sqlite` is meant to gain one; or
   (b) fold "add a UDF registration surface to `cosmic.sqlite`" into this
   item's own scope, superseding its current Non-goal.
2. Whichever is chosen, name `cosmic/sqlite/row_iter.tl` explicitly
   alongside `column.tl` in the respec'd Change, since that is where the
   raw statement/index needed for the `column_type(n)` check actually live.
