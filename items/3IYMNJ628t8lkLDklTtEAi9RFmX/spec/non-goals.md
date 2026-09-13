- **`_types/tlast.tl:349` is untouched.** It is filed under `metatable
  access` in `docs/design/cast-sites.tsv` but is neither an identity
  compare nor a metamethod fetch (see Change #6) — closing it is a
  different, single-site question this item does not answer, and
  reclassifying its TSV row to whatever class actually fits it is a
  judgment call for whoever curates the census next, not a mechanical
  part of this diff.
- **No new public `cosmic/**` module.** `cosmic.check` already exists
  and already carries this exact kind of test-probe compression
  (`refuses`, `is_exposed`); adding `metamethod` to it is not the "new
  public name" the Goal ruled out.
- **The other casts in these same four files are out of scope.**
  `cosmic/sqlite/bind.tl` has 3 non-metatable-access casts today (5
  total per `_build/casts_baseline.tl`, only 2 of which this item
  touches); `_types/tlast.tl` has 4 more (`tl compiler surface` ×2,
  `module surface record` ×2) that belong to the sibling census items
  for those classes, not this one.
- **`check.refuses` and `check.is_exposed`'s own casts are untouched.**
  They are `type-defeating test probe` sites, a different class with
  its own item.
- **No `3p/tl/tl_patch/` entry for `narrowed_declaration`'s behavior
  here.** `3p/tl/tl_patch/integer.tl` already carries a patch that
  skips `narrowed_declaration` for a different narrow case (a number
  local narrowed to integer); generalizing that patch to also skip a
  `metatable<T>` re-narrow is a checker-behavior change with its own
  cold-build staging concerns (see `1Lhz_38Wt`/`zs1K_cWnY` on this
  board for the shape such a change takes), not a mechanical part of
  closing 9 cast sites. The two-statement declare/assign split is the
  in-scope fix.
