- **`cosmic._version` itself does not move.** `cmd/cosmic/embed_gen.tl`
  keeps generating it at `cosmic/_version.lua` inside the module root,
  from `3p/cosmos/cosmos_pin.tl` and `.version`; the record it carries
  keeps its two `cosmic`/`cosmos` fields. This slice changes only who
  reads it and how.
- **`--version` output is frozen.** `cosmic --version` prints
  `cosmic-lua <cosmic> (cosmos <cosmos>, <Lua _VERSION>)` inside a
  packed binary and bare `<Lua _VERSION>` without one;
  `cosmic/version_test.tl` pins both and must pass untouched. Do not
  edit that test.
- **`cosmic._VERSION` keeps its type and value.** It stays a plain
  `string` computed at module load, `"unknown"` outside a packed
  binary — not a `VersionInfo`, not nil-able.
- **No new public module, and no other export on the `cosmic` record.**
  `version_info` and the `VersionInfo` type export are the whole
  widening; `_build/public_surface_baseline.tl` must not move.
- **Do not touch `_cli/visibility.tl`, `cosmic/doc/visibility.tl`, or
  `_build/public_surface.tl`.** The visibility rule is the constraint
  this slice designed around, not something to adjust.
- **`_make/stamp.tl`'s `BOOT_MODULES` does not move.** The boot surface
  is unchanged because `_cli/main_handlers.tl` requires no new module;
  do not add `cosmic` or `cosmic._version` to that list. `git diff
  origin/main -- _make/stamp.tl` must be empty.
- **Do not make `_cli/main_handlers.tl` call `cosmic.version_info()`.**
  It cannot until a release carrying the export is pinned — the
  bootstrap constraint above — and reaching for it turns a green tree
  into a build that fails before the gates run.
- **The other two closures under `3IOK4SZH` are not this slice.** Leave
  every other `-- cast: from any` in the tree alone — 105 lines carry
  that reason today (`git ls-files '*.tl' | xargs grep -h -- "-- cast: "
  | grep -c "from any"`), and only the six in these five files close
  here.
- **Do not edit `docs/design/casts.md`.** Its tables are a snapshot
  dated `d3e59de7`, already stale independently of this slice, and
  refreshing it is its own item (`3IQC4GeO`).
