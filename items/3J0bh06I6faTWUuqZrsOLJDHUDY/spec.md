## Question

`«HD1o_sZ5c»`'s pin bump to `cosmic-lua/cosmic`'s current release
(`2026-09-07-2b2002d`) is committed but not pushed — `cosmic-lua/work`'s
own tree fails `--check types` under the new pinned checker, so
"the tree still builds and its own test suite still passes against
the new pin" (the item's own Change) does not hold.

## Evidence

Builder `build-HD1o_sZ5c-6141b568` measured, 2026-09-07, against the
item's own worktree (branch `3J0U2KOp`, off `origin/main`, pin bump
committed as `e3c5c5b5`):

- Downloaded the new pinned binary and independently verified its
  sha256 matches `bin/cosmic.pin`'s new values before testing against
  it — ruling out a corrupt download.
- `bin/cosmic --make ci` runs fmt/check/lint/example clean (167 checks)
  under the new pin, then fails compiling `_work/store.tl` at the
  coverage stage:
  ```
  _work/store.tl:316:4: error: in assignment: got Cache (inferred at
  _work/store.tl:313:3), expected nil (inferred at _work/store.tl:303:3)
  ```
- Root cause: `ensure_index` (`_work/store.tl:299-320`) narrows
  `s.index` to `nil` after an early `if s.index ~= nil then return
  ... end`, then later assigns `s.index = c` (a `cache.Cache`) — a
  pattern the OLD (three-days-stale) pin's checker accepted and the
  NEW pin's checker now rejects, apparently as a side effect of the
  same nil-flow/narrowing work (`cosmic.ast`/PRs #1761-#1791) that
  motivated this item's bump in the first place.
- The compile failure aborts the whole `_work` compile-batch before
  the gate reaches its test-run stage at all.

## What needs deciding

`_work/store.tl:299-320` (and possibly other call sites with the same
narrow-then-reassign shape — not yet audited) needs adjusting to
satisfy the new checker's narrowing rules, OR the narrowing behavior
itself needs reconciling on the `cosmic-lua/cosmic` side if the new
checker's rejection is itself wrong. Either way this blocks the pin
bump until resolved; whoever picks this up should decide which side
owns the fix (a `work`-side type-narrowing fix is more contained;
confirm the new checker's rejection is actually correct before ruling
that out).

## Status of the rest of the item

The pin bump itself (`bin/cosmic.pin`'s two fields) is committed,
unpushed, on branch `3J0U2KOp` in the worktree at
`/home/user/wt/3J0U2KOp`, ready for whoever resumes this item once the
`_work/store.tl` compatibility gap is closed.
