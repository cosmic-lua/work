- **Fix none of the 116 sites.** Not one, in any tree. The sweep is its own
  work and its own items; a PR that both adds the gate and moves the number
  cannot be reviewed as either.
- No patch to `3p/tl/tl_patch/**` and no tl pin change. Whether the checker
  itself can be made to refuse this is a separate item, filed as a capture
  from this one, and it is gated behind the sweep by arithmetic.
- No new `--check lint` rule and no change to `_cli/lint.tl`'s `lint_file`
  composition: a rule that fires would fail on 116 sites the day it lands.
  The ratchet is the whole gate here.
- No change to `_cli/returns.tl`'s existing `check_fallible_returns`, its
  diagnostic text, or the `fallible-returns` rule name — a different
  invariant that happens to share the parser.
- No change to `_build/casts_baseline.tl`, `_build/public_surface_baseline.tl`,
  or any committed floor other than `.cosmic-coverage`.

  Corrected at implementation: the original wall said `.cosmic-coverage` too,
  and that was an error in this spec, not a rule. Every new source file needs
  a coverage row — the stage fails with `not in baseline (new file? run
  'cosmic --make coverage --baseline' and commit)` — so the wall as written
  made the slice unbuildable, and `decompose.md` already puts exactly this
  regen in scope for any slice that adds gated material. Only the two new
  files' rows may appear: `git diff .cosmic-coverage` must show two added
  lines and no other row moved. The cast floor stays untouched for a
  different reason — this slice carries no `as` cast, using an `is integer`
  guard where the template it copies casts, so a corrupt floor entry is
  named instead of coerced.
- No `docs/decisions/` record and no `docs/guides/lint.md` entry: this gate
  counts a class, it does not add a rule a contributor must learn to write
  code against.
- Do not widen `TREES` or start counting `3p/` — vendored source is not
  written here.
