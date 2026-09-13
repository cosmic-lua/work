One ref snapshot per run, one load, nothing read twice — the read verbs'
process count drops and `show`/`next` approach `find`'s 0.02 s. This is
NOT the SQL-views item («BZCt_Z5l7» decides how verbs read the cache); it
removes duplicate git work on the path that exists today, and lands
independently of it.

1. `_work/store.tl` / `_work/cache.tl`: the digest the cache validates
   against is computed from the ref snapshot the load already took — pass
   the `for_each_ref` result (or its digest) into the cache check instead
   of re-running `for-each-ref`. One snapshot per process.
2. `_work/gitread.tl` id resolution (`show ID`, and every verb taking an
   id): resolve a prefix or handle from the snapshot already in hand (the
   ref list is in memory) — zero extra processes — falling back to a
   single `for-each-ref` glob only when no snapshot exists yet.
3. `_work/gitshow.tl` (and whichever second caller reads `spec.md`): the
   spec body comes from the loaded Item (`read_specs` batched it) — delete
   the two `cat-file -p <ref>:spec.md` calls. `remote get-url origin` is
   read once per process and memoized in the store, not per render.
4. `git log` for the item's history stays: it is the one thing the load
   does not carry. Name it in the code as the one deliberate process.
5. Tests, in the diff: a `_work/cache_test.tl` case that the digest check
   never calls `refs.for_each_ref` when handed the load's snapshot (swap the
   function on the `_work.refs` module table for a counting stub around the
   call, restore it after); a `_work/gitread_test.tl` case that resolving a
   prefix and a handle against an in-memory snapshot calls `for_each_ref`
   zero times; a `_work/gitshow_test.tl` case that `show ID` renders the spec
   with `gitobj`'s `cat-file -p` path stubbed to fail, proving the body came
   from the loaded Item. Expected after the change, for the builder's own
   check with the strace command above (not recorded in the tree): `show`
   and `next` at 4 git processes (one `for-each-ref`, three `cat-file
   --batch`), `show ID` at 5 (those plus `log`). If the load's three
   `cat-file --batch` passes can become one process, do it in this PR only
   if it stays under the file caps; otherwise leave that as a note in the PR.
