Tests only. Do not edit `3p/tl/tl_patch/closure.tl`,
`3p/tl/tl_patch/narrow.tl`, `3p/tl/tl_patch/ast_cache.tl` or
`_make/patch.tl` — no patch DATA changes here, so no `--make fetch`
step and no re-derivation of `o/3p/tl/tl.lua` is in scope. Do not
correct the `note` field or the in-`replace` comment of
`closure-assigned-scan`, even though "declaration rvalues" names a
shape less precisely than the assignment-statement rvalue probed above:
touching them is a patch-data change.

Do not touch `cosmic/teal_narrowing_test.tl` (401/500) or
`cosmic/teal_test.tl` (493/500), and do not change the `checks` helper's
signature or the file's header doc comment beyond what a new test needs.

Do not widen into the adjacent live items: `3IVQJa0b` (the closure rule
also fires at LOOP sites, undescribed and unpinned) — add no loop-site
test here; `3IVSDpFq` (the metatable is-dispatch rescue is inline-only);
`3IVL4phw` / PR #1468 (trimming `table_kinded` in `narrow.tl`).

Do not add a memoization or any other change to `assigned_anywhere`, and
do not restructure the scan: those are `3IVZsiwL`'s subject.

Do not convert this file to runner mode — the runner-mode migration is
its own batch of items (`3IU6AsZC` and siblings).
