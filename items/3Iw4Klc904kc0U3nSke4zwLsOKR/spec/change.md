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
