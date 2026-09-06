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

The item's own Evidence section already carried a hint this was
under-verified: it says a PRIOR builder attempt "drafted the actual
... entry" and "came to 54 lines" over headroom, but never records
that draft having been run against the full tree (`--make check`) —
this item inherited that untested isolation assumption as settled
fact.

The draft patch (with a note documenting this exact finding and its
reproduction commands) is committed, unpushed, at `d3d8ffd` on branch
`3IpBKtB8`.

## Change

Respec this item once a real fix design exists for scoping the
widening to only the 2 `sqlite/extras.tl` sites (or otherwise making
the change tree-safe) — options to evaluate, not yet chosen:

- a call-site-scoped mechanism rather than a shared find/replace patch
  on `special_pcall_xpcall` itself (not achievable via
  `3p/tl_patch/`'s exact-match mechanism alone);
- genuine `ok`-keyed flow narrowing in the checker (materially larger
  than a single patch entry — likely its own decision record given
  the checker-design scope);
- or accept the 2 sqlite sites keep their casts and close this item as
  not viable at the patch-entry granularity, filing the real narrowing
  feature separately if it's still wanted.

Whichever direction is chosen, resume from branch `3IpBKtB8`'s
existing commit (the draft patch, its full tree-wide regression
evidence, and the `narrow-pcall-return`-vs-`narrow-pcall-zero-return`
naming/sort-order gotcha already resolved there) rather than
re-deriving the same probes.

## Non-goals

Not attempting the widening again unscoped — verified above to break
6+ existing sites tree-wide, not just this item's 2 named sites.
