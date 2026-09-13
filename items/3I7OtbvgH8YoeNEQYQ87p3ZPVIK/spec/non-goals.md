- **the four `cosmic/instrument.tl` sites STAY, and their `as integer`
  count stays at 7.** Measured 2026-08-23 at `d01ea6ac` on a detached
  worktree, cold (`--make clean && --make fetch && --make build`):
  migrating them makes `cosmic/instrument.tl` — which is in
  `_make/stamp.tl`'s `BOOT_MODULES` (line 66) — call a function that
  the running binary's embedded `cosmic.string` does not have, and the
  cold build ends `build: FAIL (generate failed)` with `invalid key
  'to_integer' in record 'str' of type record StringModule` at
  `_types/tlast_gen.tl`. Both the tree bootstrap and the pinned-release
  fallback fail identically, so no second generation recovers it. The
  same clean state with only the two `testrun.tl` sites migrated ends
  `build: PASS (511 files, 1 binary)`. That hazard is captured as
  3IIm7ZyN; the instrument half is a later wave, after it lands. This
  is NOT the coverage race of 3ICDL1lV, which merged as #1318 and is no
  longer a blocker.
- the four digit-run casts (`literal.tl:76,108`, `url.tl:54`,
  `fs/octal.tl:23`) STAY: each parses a pattern-verified digit run and
  its justification is honest; migrating them adds dead error branches
  the coverage ratchet would then count unhit.
- the three `math.floor(...) as integer` sites (`instrument.tl:111,
  117,125`) are a different class — whether the pinned tl declares
  `floor(): integer` decides if they simply delete; measure that in a
  later leftovers wave, not here.
- `_tool/testrun.tl:111` (`(128 + r.signal) as integer`) STAYS: it is
  arithmetic on an already-integer field, not a parse, so testrun keeps
  exactly one `as integer` after this wave.
- no changes to `tonumber` semantics beyond the integral-value rule
  stated above; no `cosmic.math` module; no change to the
  `InstrumentData` record's fields or to what `parse_line` returns for
  a line it rejects. Do not add `cosmic.string` to `BOOT_MODULES`.
