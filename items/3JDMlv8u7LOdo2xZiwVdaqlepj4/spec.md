## Evidence

`BQJW_iXKI`'s test-duplication audit (board item `RJmz_PAaO`, no code
change — the audit found zero duplicate test CASES) surfaced one
out-of-scope finding: `_work/gitworktree_bootstrap_test.tl` and
`_work/gitworktree_bootstrap_failure_test.tl` each independently define
a near-identical `Case` record, `git_output` helper, and `fresh()`
fixture builder:

```
$ grep -n "^local function fresh\|^local record Case\|^local function git_output" \
    _work/gitworktree_bootstrap_test.tl _work/gitworktree_bootstrap_failure_test.tl
_work/gitworktree_bootstrap_test.tl:24:local record Case
_work/gitworktree_bootstrap_test.tl:34:local function git_output(root: string, argv: {string}): string
_work/gitworktree_bootstrap_test.tl:49:local function fresh(name: string, kind: string, script?: string): Case
_work/gitworktree_bootstrap_failure_test.tl:27:local record Case
_work/gitworktree_bootstrap_failure_test.tl:37:local function git_output(root: string, argv: {string}): string
_work/gitworktree_bootstrap_failure_test.tl:45:local function fresh(name: string, kind: string, script?: string): Case
```

A direct diff of the two `fresh()` bodies shows they are byte-identical
for the `kind` branches both files use, diverging only where
`gitworktree_bootstrap_failure_test.tl` adds a `"decoy"`/`"make-bootstrap"`
branch `gitworktree_bootstrap_test.tl` doesn't need. `git_output` is
verbatim in both.

This is the same class of shared, independently-reimplemented fixture
setup that `f6YD_gyJi` (PR #123) consolidated across `store_test.tl`/
`storewrite_test.tl`/`storeref_test.tl` — that consolidation evidently
did not reach this pair. `_work/worktree_bootstrap_paths_test.tl` has
its own `Case`/`fresh()` shape too, but its own comment already notes
it deliberately mirrors `_work/worktree_runtime_test.tl`'s `fresh()`
instead — a different, more distant relationship not part of this
item's scope.

## Change

Consolidate `gitworktree_bootstrap_test.tl` and
`gitworktree_bootstrap_failure_test.tl`'s duplicated `Case` record,
`git_output` helper, and the shared portion of `fresh()` into one place
both files import — following the same shape `f6YD_gyJi` used for its
own fixture consolidation (a shared helper module, or one file's
`fresh()` extended with the other's few extra `kind` branches and the
now-single-copy `fresh()` re-exported for the sibling to use, whichever
produces the smaller diff). Do not change any test case's behavior,
inputs, or assertions — this is fixture-code deduplication only.

## Non-goals

Not touching `_work/worktree_bootstrap_paths_test.tl` — its fixture
shape mirrors `worktree_runtime_test.tl`, a different relationship
outside this item's scope. Not auditing for further test-CASE
duplication (that was `BQJW_iXKI`'s already-completed scope). Not
weakening, thinning, or removing any test case to make the consolidation
easier.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
