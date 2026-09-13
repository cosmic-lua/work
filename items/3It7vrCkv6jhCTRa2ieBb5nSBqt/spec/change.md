Blocked until «p1i3_tUj4» publishes a real `cosmic.fuzz` surface —
concretely, its own child 8 ("the publishing move itself: placement,
`--docs` entry, examples, and the public-module-surface baseline"), not
yet filed as its own item as of 2026-09-05. Once it lands:

1. Delete `_fuzz/driver.tl`, `_fuzz/source.tl`, `_fuzz/shrink.tl` from
   this repo.
2. Update `_fuzz/itemtree_fuzz_test.tl` and `_fuzz/priority_fuzz_test.tl`'s
   `require("_fuzz.driver")`/`require("_fuzz.source")` lines to the
   published module's actual name.
3. Re-run `bin/cosmic --make test _fuzz` and `--make check _fuzz` to
   confirm both property files pass unchanged — the properties
   themselves do not move, only where the harness comes from.
4. Remove `_fuzz/driver.tl`, `_fuzz/shrink.tl` and `_fuzz/source.tl`'s
   rows from `.cosmic-coverage` rather than leaving stale entries for
   files that no longer exist.

If child 8 is filed as its own item before this is pulled, retarget this
item's blocker to it directly — the block here is on the epic only
because the specific milestone this depends on has no id of its own yet.
