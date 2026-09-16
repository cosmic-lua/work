`primary` in `_work/worktree_paths.tl` trusts the first `git worktree list`
entry as the main checkout. For a repository initialised or cloned with
`--separate-git-dir`, git lists the git directory there, its
`rev-parse --show-toplevel` fails, and `primary` refuses with "no usable
nonbare primary worktree" even when the selected root IS the primary product
checkout. Because `repository_map.resolve` routes through `primary`, `take`,
`verdict`, `done`, `brief`, review-range resolution and snapshot validation
all refuse such a checkout. Confirm with a `git init --separate-git-dir`
fixture before editing.

When the first listed entry is not a work tree toplevel, accept the selected
root as the primary when its own `--show-toplevel` equals itself and its
`--git-common-dir` resolves to the same directory as the listed entry's;
that is registered metadata, not a guess. Otherwise keep the refusal.

Regression in `_work/worktree_paths_test.tl`: a `--separate-git-dir`
repository resolves to itself as primary; a linked worktree of it still
resolves to that primary; a bare repository still refuses.
