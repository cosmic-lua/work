## Evidence

This repo's `_fuzz/driver.tl`, `_fuzz/source.tl` and `_fuzz/shrink.tl` (PR
cosmic-lua/work#20, 2026-09-05) are a verbatim copy of
cosmic-lua/cosmic's own internal `_fuzz/` harness, made because no public
module exists yet for a consuming project to import instead. This is a
live instance of exactly the distribution cost «p1i3_tUj4»
("cosmic.fuzz: a published fuzzing facility user projects can point at
their own code") names as its stated outcome: "a user project can fuzz
its own code with one import" — which this repo currently cannot do; it
has to carry and independently update its own fork of three files
instead.

The copied files have no cosmic-repo-specific dependencies — only
public `cosmic.*` requires (`cosmic.child`, `cosmic.codec`, `cosmic.env`,
`cosmic.proc`, `cosmic.rand`) plus their own internal `_fuzz.*`
cross-requires — so once a public module exists the migration is
mechanical: `grep -n require _fuzz/driver.tl _fuzz/source.tl
_fuzz/shrink.tl` on 2026-09-05 shows nothing this repo's own code needs
to keep working around.

## Change

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

## Non-goals

Writing any new fuzz properties for gitboard; changing what
`itemtree_fuzz_test.tl`/`priority_fuzz_test.tl` test; any part of
`cosmic.fuzz`'s own design, shape or publishing move — that is
«p1i3_tUj4» and its children, not this item.
