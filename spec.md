## Evidence

Builder session `build-rLV8_r8a5-fe8c92c8` (2026-09-06) drafted the
patch entry the item's `## Change` calls for
(`3p/tl/tl_patch/pcall_return.tl`, key `pcall-return-widen`, applying
after `narrow-pcall-zero-return`'s own entry — confirmed by name-sort
order, since `_make/patch.tl` applies entries in a GLOBAL sorted-name
order across the whole `tl_patch/` directory, not per-file; the
spec's own literal example key `narrow-pcall-return` sorts BEFORE
`narrow-pcall-zero-return` and fails "anchor occurs 0 times" on a
from-scratch fetch for exactly this reason — worth naming as a gotcha
in `_make/patch.tl`'s own doc comment for the next author in this
directory).

The item's central premise — a known-signature, non-zero-arity
`pcall(f, ...)`'s SUCCESS-arm slot 2 is already typed from `f`'s own
return type today — was confirmed true. But the widening itself is
**not scoped to `cosmic/sqlite/extras.tl`'s 2 sites as assumed**:
Teal has no discriminated-tuple-union mechanism keyed to the
companion `ok` boolean at position 1, so widening slot 2's DECLARED
type (to admit the raised-failure type alongside the success type)
changes the type of every non-zero-arity `pcall(known_fn, ...)` call
in the tree, not just the two named sites. Verified two ways with the
patch applied:

    $ o/bin/cosmic --check types cosmic/shm.tl
    # 6 new errors: read/load/atomic/cmpxchg/wait/mapshared

    $ o/bin/cosmic --make check
    # additional failures: _make/policy_test.tl:376, _eval/score_test.tl:143,
    # _fuzz/shrink.tl:41

All of these are existing, currently-passing `local ok, v =
pcall(known_fn, ...)` idioms elsewhere in the tree that read `v`
unguarded after the idiom's usual early-return-on-`!ok` — today this
works only because slot 2 keeps `f`'s EXACT success type; widening it
tree-wide breaks every one of them.

Research session `research-IOA7_CLf5-748ecc95` (2026-09-06)
independently re-verified this premise from scratch (the prior
session's draft branch `3IpBKtB8` was gone — recreated the patch entry
by hand, mirroring `narrow-pcall-zero-return`'s own shape) and
reproduced the identical 6 + 3 failures. It also found that the 2
sites this item was scoped to help — `cosmic/sqlite/extras.tl`'s
`db:transaction` and `db:savepoint` (lines 63, 106) — already carry a
working, lint-compliant fix today: a per-call-site `(verdict as
string) -- cast: pcall slot 2 is the raised error, typed boolean from
TxFn`, matching the `cast-justify` rule and the checker's own "cast
after a guard" hint verbatim. Neither site is actually broken or
blocked.

## Change

Closed, no code change. The tree-wide-breakage premise was re-verified
independently (patch re-derived from scratch since branch `3IpBKtB8`
was gone; `o/bin/cosmic --check types cosmic/shm.tl` reproduces the
same 6 errors — read/load/atomic/cmpxchg/wait/mapshared — and
`o/bin/cosmic --make check` reproduces the same 3 additional failures
— `_make/policy_test.tl:376`, `_eval/score_test.tl:143`,
`_fuzz/shrink.tl:41` — the original spec named).

Of the three options weighed: a call-site-scoped mechanism outside
`3p/tl_patch`'s shared-function-body patch already exists and is
already in use — `cosmic/sqlite/extras.tl`'s 2 sites already carry a
working `-- cast: ... / (verdict as string)` fix, lint-compliant under
`cast-justify` and matching the checker's own "cast after a guard"
hint. Genuine ok-keyed flow narrowing in the checker (discriminated
narrowing of a pcall tuple keyed to its own boolean) would be a real
fix but is a materially larger checker-design change needing its own
decision record first, with no concrete forcing need beyond these 2
already-solved sites.

Closing as not viable at the patch-entry granularity: the 2 sites this
item targeted already work correctly with their existing casts — no
further change is needed here.

## Non-goals

Not widening pcall's declared return type again, scoped or unscoped —
confirmed twice now (this pass and the prior session) to break sites
tree-wide with no scoping mechanism available in `3p/tl_patch`. Not
filing the ok-keyed narrowing checker feature as a live item: no
concrete site needs it today (both named call sites already have a
working, idiomatic cast); revisit only if a future site's cast becomes
genuinely unwieldy, at which point it needs its own decision record
before implementation.
