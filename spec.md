## Evidence

`fsck`'s per-item tree audit spawns separate git processes per item instead
of batching, unlike every other whole-board read. `_work/gitfsck.tl:180-197`
(`cmd_fsck`) calls `store.list` once (batched, per `_work/store.tl`'s own
doc: "three git processes for the whole board, whatever its size"), then
loops `for _, it in ipairs(all) do local p = tree_problem(s, it, ...)` —
once per item, no batching. `tree_problem` (`gitfsck.tl:107-126`) calls
`gitobj.tree_of(s.root, observed_sha)`, which is a bare
`child.run({"git", "rev-parse", commit_sha .. "^{tree}"})`
(`_work/gitobj.tl:58-59`) — one `git rev-parse` per item — then
`itemtree.build_tree` re-encodes the item's canonical tree to compare
hashes, which (per `gitobj.tl:82`, `git mktree`, and the `hash-object`
call at `gitobj.tl:42`) needs at least one more git process per item to
recompute the tree it compares against.

Measured 2026-09-04 by «98RT_EE0A»'s own evidence, live board (915 items,
warm cache): `fsck` 14.6s, 4,465 processes (4,464 git) — ~4.9 git
processes per item, matching a per-item `rev-parse` + `mktree` (+ blob
`hash-object` calls the tree's entries need). Reproduced independently
today (2026-09-05) against the same live board, synced: `time
o/bin/gitboard fsck` → 13.8s real, `gitboard-fsck: ok (922 items)`. Every
other whole-board verb (`show`, `next`) reads all items through
`store.list`'s fixed ~3-6 process batch and stays under 0.2s at this size;
`fsck` is the one verb whose cost scales with item count at roughly
constant-per-item git-process overhead, confirmed linear in a separate
sandbox measurement (10 items: 126ms; 1,600 items: 18,195ms — ~11-12ms/item
throughout).

This is orthogonal to «BZCt_Z5l7» (routing `flow.tl`/`priority.tl` readers
through the SQL cache): `fsck` audits the raw git objects as ground truth
against the cache/canonical form, so it cannot read from the cache for the
tree-identity check without defeating the point of the audit. It is also
orthogonal to «cwi5_ntHB» (already in review), which batches `show`/`show
ID`/`next`'s redundant ref snapshots but does not touch `gitfsck.tl` at
all.

## Change

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

## Non-goals

Changing `fsck`'s reported problems or exit codes; the SQL-views seam
(«BZCt_Z5l7»); `show`/`show ID`/`next`'s own process counts («cwi5_ntHB»,
already in review); adding a scheduled/CI-only fast fsck mode — this is
about the existing verb's cost, not a new one.
