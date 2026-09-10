## Current refinement — native Cosmic reuse review

This refinement supersedes conflicting implementation assumptions in the historical spec below; its original evidence is retained for context.

The existing choice of public `cosmic.ast` is correct. Use parse/walk/match/find_all (and rewrite only where safe) rather than grep or raw tl internals. A syntax match does not establish `T | nil`, identity across shadowed bindings, or control-flow ordering. Scope traversal to the containing function and verify guard/assignment refer to the same target; cover alternate guards, nested functions, shadowing, unrelated fields, and already-fixed cases. Use checker-backed reproductions to validate semantic claims. If public AST APIs cannot express a required relation cleanly, capture an executable gap probe and file a reusable Cosmic extension before duplicating generic analysis in GitBoard. Do not invent a general data-flow API without such evidence; retain the one-time sweep scope.

## Evidence

Board item «HD1o_sZ5c» bumped `cosmic-lua/work`'s own `bin/cosmic.pin`
to `cosmic-lua/cosmic`'s current release, landing the `cosmic.ast`/
`--find`/`--rewrite` chain in `work` checkouts for the first time —
confirmed live, 2026-09-07: `bin/cosmic --find` previously refused
with `unknown option: --find` in a `work` checkout, now runs.

That same pin bump surfaced a real bug in `_work/store.tl`'s
`ensure_index` (guard a `T | nil` record field non-nil with an early
return, then reassign it later in the same function) — filed and
fixed as «OLJD_HUDY», with the underlying checker regression it
exposed filed separately on `cosmic-lua/cosmic` as «m1fA_LUmS». That
investigation grep-swept `_work/*.tl` for the same shape
(`grep -rn "if [a-z_]*\.[a-z_]* ~= nil then" _work/*.tl`) and found
only two other hits (`_work/gitshow.tl:67`, `_work/read.tl:336`),
neither reassigning the guarded field afterward — but a plain regex
only catches ONE syntactic spelling of the guard (`~= nil`, un-negated,
no `not`, no truthy check) and cannot see whether a MATCHING field is
reassigned later in the same function at all; it was a stopgap, not a
structural check.

With `--find` now available in a `work` checkout, this can be swept
properly with `cosmic.ast.match` instead of grep — the same
capability `cosmic-lua/cosmic`'s own spec-bar doctrine already expects
of any "Change over N sites" claim (`gitboard help bar`: "a Change
over N sites states the PATTERN that selects them and the count
`cosmic --find PATTERN [PATH...]` printed").

## Change

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

## Non-goals

Not touching `cosmic-lua/cosmic`'s own tree — a separate, much larger
codebase; a sweep there is its own item if someone wants one, not
scoped here. Not fixing the underlying checker bug itself (that is
«m1fA_LUmS», filed on `cosmic-lua/cosmic`). Not adding a permanent
lint rule or CI ratchet for this pattern — a one-time sweep, since
`work` has no `_build/`-style ratchet infrastructure of its own; if
the sweep turns up more than a couple of hits, note that as a finding
for a follow-on item, don't build the ratchet here.

## Access

cosmic-lua/work, read and write on a branch; no other repository.

