`gitboard worktree` resolves its checkout path against the caller's current
directory, so a worktree created while sitting inside another item's worktree
nests inside it. It compounds: each generation nests in the last.

Measured this session, third review round:

    /home/user/wt/work/BK2V8tI0/wt/work/px0XYxR8/wt/work/9cnWGG8u/9751532864df

Three item handles deep, and only the last owns the tree. Consequences: path
length grows without bound across a session; the worktrees of one item cannot
be enumerated; and deleting one item's tree silently takes unrelated items'
checkouts with it.

A second reproducer, 2026-09-15, shows the cwd is NOT the whole cause and
may not be the cause at all. The verb ran with cwd `/home/user/cosmic`,
confirmed by a `pwd` in the same command — not inside any worktree — and
still produced:

    /home/user/wt/work/S4pFDMGT/wt/work/bjHfEkuj/e2d2417497bc

nested inside a DIFFERENT item's worktree. What named the real cause was
the next invocation, after those worktrees were removed:

    gitboard-worktree: repository path is not a directory:
      /home/user/wt/work/S4pFDMGT/82af11027fd2

That path is a WORKTREE of cosmic-lua/work, not the configured product
checkout. `gitboard.repository` mapped `cosmic-lua/work=/home/user/work`
in the board checkout's local config, and the verb resolved the product
repository to one of that repo's worktrees instead — the nesting is where
that wrong root lands, not an artifact of the caller's cwd. Passing
`--repo-dir /home/user/work` explicitly produced the correct
`/home/user/wt/work/bjHfEkuj/e2d2417497bc` from the same cwd, which
isolates the defect to resolution rather than to path composition.

So fix the RESOLUTION: `repository_map.resolve` must return the product
repository's own root, never one of its worktrees. Anchoring an
already-wrong root absolutely would keep producing nested paths.

Note for whoever builds this: recovery needs two steps, not one.
`git worktree remove` leaves the claim branch behind, and the next attempt
refuses with `branch work/<handle>/<claim> already exists in <repo> — never
reused`, so the leftover branch must be deleted too.

`_work/gitworktree.tl` derives the path from the product checkout
(`grep -n "local path = claim.worktree(checkout, branch)" _work/gitworktree.tl`)
via `repository_map.resolve`, which returns a path that can be relative to the
caller. Resolve it to an absolute path anchored at the product repository's own
root before `claim.worktree` composes the checkout path, so the result is
independent of where the verb was run from.

Regression: a test that runs `cmd_worktree` with the process cwd set inside an
unrelated worktree and asserts the resulting path is under the product root,
not under the cwd.
