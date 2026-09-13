- **The 500-line cap does not move** — no `file-length` exemption for
  patch data; the rejected alternative is recorded here: an exemption
  relaxes a convention the work system's hard rules say is never
  relaxed to make work fit, and splitting is the enablement the same
  rules prescribe.
- **No entry is edited, added, or removed.** Twenty entries in, twenty
  out, byte-identical bodies; the four pending patch items land their
  entries AFTER this, in `3p/tl/tl_patch/narrow.tl`.
- **No pin change, no `o/3p/**` expectation change**: the applied
  output must be byte-identical (the oracle).
- **`patch.read`'s per-file validation and the Edit record are
  untouched**; only resolution and aggregation grow.
- **No model/convention change**: `*_patch/` files are ordinary tree
  files, and nothing new is excluded from any gate.
- **Frozen**: the anchor contract (find matches exactly once, per
  file it names), `cosmic.literal` as the reader, the archive-pin
  guard in fetch.
