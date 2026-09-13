`_work/gitview.tl`, the doing-row renderer: when an item's `reviewer`
is non-empty, append ` reviewer:<session>` after the `pr:N` mark, so a
row reads `[review] @build-QYqs_nEsq-f6f470de pr:46
reviewer:review-QYqs_nEsq-a36d13ac`. Keep the file under 500: if the
line does not fit, move `id_line` and its doc comment to
`_work/tail.tl` first (the same relocation «duSw_TyDF» names — whichever
lands second rebases onto it). `_work/gitview_test.tl` (or wherever
doing rows are asserted — `grep -n 'pr:' _work/*_test.tl`): one row with
a reviewer prints it, one without prints nothing extra.

`gitboard help orchestrate`, the review fan-out bullet: "a doing row
carrying `reviewer:` is already claimed — skip it, never `--force`."
