Consolidate `gitworktree_bootstrap_test.tl` and
`gitworktree_bootstrap_failure_test.tl`'s duplicated `Case` record,
`git_output` helper, and the shared portion of `fresh()` into one place
both files import — following the same shape `f6YD_gyJi` used for its
own fixture consolidation (a shared helper module, or one file's
`fresh()` extended with the other's few extra `kind` branches and the
now-single-copy `fresh()` re-exported for the sibling to use, whichever
produces the smaller diff). Do not change any test case's behavior,
inputs, or assertions — this is fixture-code deduplication only.
