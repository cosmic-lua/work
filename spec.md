## Evidence

Every whole-board load spawns `git cat-file --batch` three times: once for
each item's root tree entries (meta, held, edges), once for the edge kinds'
subtrees, once for every content blob (`_work/gitread.tl`, the three passes
its `load` documents; `strace -f -e trace=execve` on `o/bootstrap/gitboard
show` against the live board, 2026-09-04, shows `for-each-ref` then
`cat-file --batch` ×3). Each pass is a full process at roughly 25 ms here,
so a warm `show` at 5 processes after cosmic-lua/work#18 spends three of
them on one logical read. `cat-file --batch` reads requests from stdin and
answers in order, so a single process can serve all three passes if the
caller writes the next round of requests after reading the previous round's
answers — a streaming client instead of three run-to-completion ones.
`_work/gitobj.tl`'s `cat_file_batch` (line ~166) is the run-to-completion
helper the passes use; `cosmic.child` has a streaming interface (check
`cosmic --docs child` for `start` with stdin/stdout pipes).

Ready when: the store split («Bkbr_5S1U», PR #21) is on main —
`git log --oneline origin/main | grep -c "(#21)"` prints 1 (a squash merge
carries the PR number, not the branch); `store.tl` is then the read half at
375 lines.

## Change

One `cat-file --batch` process per load.

1. `_work/gitobj.tl`: a `batch_session(root)` that starts one `git cat-file
   --batch` through `cosmic.child`'s streaming API and exposes
   `request(shas) -> {sha: BatchEntry}` callable repeatedly, plus `close()`.
   The existing `cat_file_batch` becomes `batch_session` + one request +
   close, so every current caller is unchanged.
2. `_work/gitread.tl` `load` (and `_work/gitreadmany.tl` `load_many`): open
   one session, issue the three rounds through it, close it. Parsing is
   untouched.
3. Tests: `_work/gitobj_test.tl` covers a session answering two rounds
   where the second round's shas come from the first round's answers, a
   missing sha in a round (`<sha> missing` line) not breaking later rounds,
   and close-after-error; `_work/gitread_test.tl` (from #18) asserts a
   load costs exactly one `cat-file` spawn (count via the module-table stub
   pattern #18 introduced). Expected, for the builder's own strace check:
   `show` at 3 git processes (`for-each-ref`, one `cat-file --batch`, the
   cache's own read), `show ID` at 4.

## Non-goals

Reading Items from the cache instead of git («BZCt_Z5l7»); changing the
tree layout or the batch line format; the mutation path («5x5P_O61f»).
