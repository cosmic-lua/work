`gitboard worktree` resolves its checkout path against the caller's current
directory, so a worktree created while sitting inside another item's worktree
nests inside it. It compounds: each generation nests in the last.

Measured this session, third review round:

    /home/user/wt/work/BK2V8tI0/wt/work/px0XYxR8/wt/work/9cnWGG8u/9751532864df

Three item handles deep, and only the last owns the tree. Consequences: path
length grows without bound across a session; the worktrees of one item cannot
be enumerated; and deleting one item's tree silently takes unrelated items'
checkouts with it.

`_work/gitworktree.tl` derives the path from the product checkout
(`grep -n "local path = claim.worktree(checkout, branch)" _work/gitworktree.tl`)
via `repository_map.resolve`, which returns a path that can be relative to the
caller. Resolve it to an absolute path anchored at the product repository's own
root before `claim.worktree` composes the checkout path, so the result is
independent of where the verb was run from.

Regression: a test that runs `cmd_worktree` with the process cwd set inside an
unrelated worktree and asserts the resulting path is under the product root,
not under the cwd.
