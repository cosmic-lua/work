`3p/cosmos/cosmos_pin.tl`: bump `version`/`sha256` to a cosmos release
at or after `2026.09.02-d88e994fc` (the release notes/SHA256SUMS name
the exact artifact). `_cli/main_handlers.tl`: fix the four flagged
`unix.mkstemp` callers to use the `MkstempPath` record's `.path` field
per the new binding contract, matching whatever narrower type
`cosmo.d.tl` now generates for `unix.mkstemp`'s second return.

Gate: `bin/cosmic --make ci` ends `ci: PASS` against the bumped pin,
and `pragma_module_list` reports an `fts5` row from a fresh build.
