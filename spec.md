## Evidence

PR #1787's review (work item «B6bC_kqMZ») found two of the casts allowlist's explicit residuals avoidable by a scoped pattern instead: `_build/casts_kinds.tl:170` — `cosmic/fs/walk.tl`'s "generic T" site (`ctx = ctx or {} as T`) is explicit only because no scoped pattern was tried, even though every "generic T" cast targets the literal identifier `T` and "userdata boundary"'s own predicate already excludes single-char names from collision in the same file; and `_build/casts_kinds.tl:261-268` "binding constant by name", whose one site lives in `cosmic/quicksand/caps.tl`, a file that hosts no other kind's casts — a `where`-scoped plain pattern would suffice with no explicit entry. Neither finding was fixed inside #1787 since it landed the mechanism, not a maximally-tight allowlist.

## Change

Replace the two explicit entries with scoped patterns: "generic T" gets `pattern = "$X as T"` (or the grammar's literal-type-name form) scoped to `where = {"cosmic/fs/walk.tl"}` (or wider once verified against the rest of the tree); "binding constant by name" gets its existing pattern (or `$X as $T`) scoped to `where = {"cosmic/quicksand/caps.tl"}`. Run `_build/casts_test.tl` after each change — the exact-one-kind and ceiling checks must still pass with the explicit list for that kind now empty (or the kind's `explicit` field removed).

## Non-goals

No other kind's residual is touched; no reclassification.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.

## Ready when

`_build/casts_kinds.tl`'s "generic T" and "binding constant by name" entries carry no `explicit` sites, and `_build/casts_test.tl` passes.
