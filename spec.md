## Change

The live board is on layout 2 and no reader interprets any edge kind,
so the generic `edges/<kind>/<id>` carry-forward exists only for
`gitboard migrate` to read layout-1 trees. Delete both: the `migrate`
verb (`_work/gitmigrate*.tl`, `_work/storemigrate.tl`, its dispatch
and command-table entry, `gitread.list`'s `allow_old_format`
parameter, `gitwrite.Request`'s `drop_held` and `extra_commits`,
`format.refusal`'s pointer at `migrate`), and `Item.other_edges` with
every `edges` reader and writer in `_work/itemtree.tl`,
`_work/gitread.tl`, `_work/gitobj.tl`, `_work/fastimport.tl`, and
`_work/gitfsck.tl`'s unknown-edge-kind finding. An `edges` entry in a
tree is then a decode problem, like `held`. Measure first: `grep -ln
"other_edges\|edges/" _work/*.tl` — the count and list go in the PR.
Keep `_work/itemtree_test.tl`'s old-layout test only as far as it
asserts the decode problem.
