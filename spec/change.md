`_work/item.tl:240` (or the `new` verb's own check in
`_work/gitgraph.tl`, whichever runs first for `new`): when the refused
field is `repo` or `base` on a parentless `new`, the refusal reads
"a root carries no repo: pass `--parent ID` to file it under an
outcome, or `new` it bare and `attach`, then `set ID --repo`". Other
fields keep the current text. `gitboard help new`'s `--repo` option
text gains "(needs --parent)".

`_work/gitgraph_test.tl`: pin the refusal text for `--repo` without
`--parent`, and that `--parent` plus `--repo` succeeds.
