In `_work/gitgraph.tl`'s `cmd_attach`, after resolving `it` and before
`gate.commit_and_publish`, find whichever item in `index` currently has
`id` in its `order` list (there is at most one, since `order` should be
a partition by construction) and, if it is not `parent_item` itself,
remove `id` from that item's `order` and add it to `also` (the
`gate.containered`/`add_once` set already used for the new-parent case
at line 236) so the edit rides the same commit. Add a case to
`_work/gitattach_test.tl` that: ranks a child under outcome A
(`rank ID --last`), attaches it to outcome B with neither `--before`
nor `--after`, then asserts `fsck` reports zero problems and A's
`order` (read via `store.list`) no longer contains `ID`. Extend
`_work/gitfsck_test.tl` (if it does not already) with a case that
seeds exactly this stale-order shape and asserts `fsck` catches it —
guarding the detector this item's own reproduction relied on.
