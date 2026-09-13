Batch `tree_problem`'s two git operations across the whole board the same
way `store.list` batches item reads, rather than one `rev-parse`/`mktree`
pair per item.

1. `_work/gitobj.tl`: add a batched sibling to `tree_of` that reads every
   named commit's `tree` line from one `git cat-file --batch` pass instead
   of one `rev-parse` each — `gitread.list` already does a `cat-file
   --batch` pass over the same commits for other fields; either reuse that
   parsed output (the tree oid is the commit object's first line) or add
   one dedicated batched pass, whichever keeps `gitfsck.tl` under its line
   cap.
2. `_work/itemtree.tl` (or wherever `build_tree`'s git calls live):
   determine whether `git mktree`/`hash-object` can run once against a
   piped batch of every item's rebuilt tree content, or whether the
   canonical tree hash can be computed in-process instead of shelling to
   git at all — `cwi5_ntHB`'s spec already names "the in-Lua hashing
   change" as planned for the mutation write path; if that lands first,
   `fsck`'s rebuild-and-compare can likely reuse it directly instead of
   duplicating a second in-Lua hasher. Record which path was taken and why.
3. Tests: a `_work/gitfsck_test.tl` case asserting `tree_problem`'s git
   process count no longer scales with item count (stub `child.run` with a
   counting wrapper the way `cwi5_ntHB`'s planned tests do, assert a fixed
   count across a 5-item and a 50-item fixture board).
4. Re-measure with the same command 98RT_EE0A used
   (`strace -f -e trace=execve` on `fsck` against a generated fixture, once
   «98RT_EE0A» lands) and record the new process count and wall time in the
   PR description.
