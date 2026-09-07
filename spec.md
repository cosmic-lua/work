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

## Resolution (2026-09-07, second session)

Decided: split. Both sides own a fix, for different reasons.

**Work-side (applied, unblocks the pin bump now):** cache `s.index`
into a local (`local existing = s.index`) before narrowing on it, so
the checker never records a narrow fact against the FIELD, only
against the local — the guard's `if s.index ~= nil` becomes
`if existing ~= nil`, and the later `s.index = c` is then checked
against the field's declared type as normal. This mirrors `close()`'s
existing style two functions below (`local c = s.index; if c == nil
then ...`), so it's not a new pattern in this file, just applied
consistently. Committed as `4e19634e` on the item's own branch
(`3J0U2KOp`); `bin/cosmic --make ci` passes clean (4 stages, 85.0%
coverage) with the pin bump and this fix together, merged onto current
`origin/main`.

**Cosmic-side (filed separately, not blocking):** this is a genuine
checker bug, not intended stricter behavior — confirmed by an
independent investigation, isolated to a minimal repro, and traced to
`3p/tl/tl_patch/narrow_record_field.tl` (landed in `cosmic-lua/cosmic`
PR #1743 / board item «FePr_L4FB»): the patch's own
`narrow-record-field-assignment` hunk invalidates a field's narrow
fact on write via `drop_field_narrows`, but does so AFTER the
assignment's expected type has already been derived from the (still
live) narrow fact rather than the field's declared type — a bug
against the patch's own stated goal
(`docs/design/casts.md`'s "record union after guard" section: "invalidated
by ANY assignment to it"). No other site in `cosmic-lua/cosmic`'s own
tree hits this (every existing guarded field there is a non-union
type, which the patch correctly skips), so it wasn't caught until
`work`'s `Store.index: cache.Cache | nil` — the first `T | nil` field
in either repo that is both guarded and reassigned — exercised it via
this pin bump. Filed as «m1fA_LUmS» (`repo: cosmic-lua/cosmic`), with
the full repro, root-cause trace, and two candidate fix mechanisms.
The work-side fix above does not depend on it landing.
