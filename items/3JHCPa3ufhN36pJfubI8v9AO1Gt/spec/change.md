The format-5 migration (#163) shipped as one atomic push over every ref
plus the marker. The live run could not be pushed that way: the egress
proxy the session pushes through refuses any receive-pack command list
above roughly 50–100 ref updates with a synthesized `403` (1 and 50 pass,
100 fails, a 6 MB body passes, namespaces are not the trigger, deletions
are refused the same way). The run was therefore made in 29 atomic
batches of ≤50 refs with a locally patched `migrate`; this item lands that
patch so the tree carries what actually ran, and so a rerun after a
partial push is never destructive again.

Three things, all in `_work/gitmigrate.tl`, `_work/gitmigrate_cli.tl`,
`_work/gitcommands.tl` and `_work/gitboard.tl`:

1. **Skip what landed.** A tip whose commit subject is already
   `migrate <handle> to format <CURRENT>` (the subject `migration_commit`
   writes, factored into `migration_subject`) is counted `skipped` and
   left alone. The shipped code reads such a tip's absent `spec.md` as an
   empty spec and would rewrite the item with an empty Change — measured
   on the fixture, and the reason the live run needed the patch before
   its first partial push. A `spec/` tree probe is NOT the mark: an item
   with an empty spec writes no `spec/` subtree at all.
2. **`--limit N`** rewrites at most N unmigrated items in this
   transaction; the rest are counted `remaining`. **`--only NAMESPACE`**
   restricts the batch to `refs/heads/<NAMESPACE>/` (`ended`, `items`).
   An empty selection is refused (`nothing to migrate in this selection`)
   rather than pushing a marker over unmigrated items.
3. **The marker rides only the batch that leaves `remaining == 0`.** Until
   then the board keeps refusing the format-5 build — the same dark
   window one push has. A local-only board applies a partial batch
   without the cache rebuild the final one does. The verdict line grows
   `skipped=` and `remaining=`, and a partial batch says so: `the marker
   moves with the last batch`.

`Outcome` gains `skipped` and `remaining`. The test file gains one case:
`limit=2` moves 2 and leaves the marker; a rerun skips 2, moves the rest
and moves the marker, with the first batch's tips byte-identical; a third
run reports current; `--only ended` on a board with no `ended/` refs is
refused. All existing cases unchanged. `ci: PASS`.
