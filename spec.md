## Evidence

`rhKJ_HSQd` (cosmic-lua/cosmopolitan) adds `unix.E`/`unix.SIG` as
typed `{string: integer}` maps. Once it lands, four casts in
`cosmic-lua/cosmic` close: `cosmic/errno.tl:52` (`code_of`),
`cosmic/errno.tl:113-124` (the redundant `codes`/`ERRNO_NAMES`
construction), and `cosmic/quicksand/proc.tl:270` + `:273`
(`become_init`'s `by_name` alias and lookup) — see `rhKJ_HSQd`'s own
Evidence for the full detail on all four.

Same staging shape as `VHkK_aA5k`'s sibling item and `zs1K_cWnY`:
`cosmic-lua/cosmopolitan` publishes a `cosmos.zip` release on every
push to master; `cosmic-lua/cosmic` pins it by version + sha256 in
`3p/cosmos/cosmos_pin.tl`. The new bindings are not usable from
`cosmic-lua/cosmic` until (a) `rhKJ_HSQd` merges, (b) a `cosmos`
release exists descending from that merge, and (c)
`3p/cosmos/cosmos_pin.tl` is bumped to name it.

## Change

Ready when: `rhKJ_HSQd` is `done` (merge commit sha recorded), AND a
`cosmos` release exists descending from that commit (verify with
`git merge-base --is-ancestor <rhKJ_HSQd-merge-sha> <release-tag-sha>`
in the `cosmic-lua/cosmopolitan` checkout), AND
`3p/cosmos/cosmos_pin.tl` is bumped to (or already at) that release.
Until all three hold, this item is not resolvable.

Once ready:

- `3p/cosmos/cosmos_pin.tl`: bump to the qualifying release, if not
  already there when this is picked up.
- `cosmic/errno.tl:52`: replace the cast with `unix.E[name]`.
- `cosmic/errno.tl:93,113-124`: delete `ERRNO_NAMES` and replace the
  hand-built `codes` table with `unix.E` directly (or a shallow copy —
  check whether anything mutates `errno.codes` at runtime before
  deciding aliasing is safe).
- `cosmic/quicksand/proc.tl:270-273`: replace `by_name`'s construction
  and lookup with a direct `unix.SIG[s]`.
- Regenerate/reconcile per this repo's standard cast-closing procedure.
- `bin/cosmic --make ci` ends `ci: PASS`.

## Non-goals

Not `cosmic/quicksand/caps.tl:63` (`CAP_*`) — that is a separate,
same-shaped item (filed as a follow-up to `rhKJ_HSQd`), with its own
staging once its own cosmopolitan-side binding lands. Not
re-litigating `unix.E`/`unix.SIG`'s own shape — that is `rhKJ_HSQd`'s
scope, already landed by the time this item is ready.
