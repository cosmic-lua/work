Using `bin/cosmic --find` (`cosmic.ast.match`, `$NAME`/`$$$NAME`
captures — `cosmic --examples ast` has worked patterns) against
`cosmic-lua/work`'s own `_work/*.tl` tree, write and run a structural
pattern (or a short Lua/Teal script using `cosmic.ast` directly if a
single CLI pattern can't express "guard, then a later reassignment of
the SAME target in the same function" — the CLI's pattern language
may not support that two-part shape in one query, confirm before
assuming it does) that finds every function where a `T | nil` record
field is:
1. read in a boolean guard (any spelling: `~= nil`, `== nil` negated,
   `not $OBJ.$FIELD`, or a truthy check), AND
2. assigned a non-nil value to the SAME field later in the same
   function body.

Report the full hit list (file:line pairs) as this item's own
Evidence-quality output. For every hit besides `_work/store.tl`'s
already-fixed `ensure_index`, apply the SAME fix shape that item
used: cache the field into a local before narrowing on it, matching
whatever nearby idiom already exists in that file (e.g. `close()`'s
style in `store.tl`) or introducing one if none exists. Confirm each
fix with `bin/cosmic --check types <file>` before and after (before:
passes today under the CURRENT pin, since this bug only bites under
`cosmic-lua/cosmic`'s post-2026-09-07 checker — that's fine, the fix
is preventive, not fixing a currently-broken build). Run
`bin/cosmic --make ci` once at the end.
