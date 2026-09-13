- **No contract change**: return shapes, error values, constants and
  `definitions.lua` untouched; an alignment attribute changes no
  observable behavior.
- **No scenario edits**, no `--samples`/`--min-secs` overrides, no
  gate weakening; never local-vs-released comparisons.
- **No revert of `354c17e08`** — DecodeLua is shipped API cosmic
  already consumes (`cosmic.literal` compact path); the fix
  neutralizes the side effect, not the feature.
- **No release.yml dispatch and no pin bump** — 3ISVlHT6 owns the
  bump once a release publishes green.
- **No default-mode accept/reject decisions** — rel-vs-rel only for
  the layout question; default mode is for the correctness gate.
- **A cosmic-side tree change is out of scope**; only
  `o/3p/cosmos/lua` varies between measured sides.
