- **No mechanism change** — `_make/patch.tl`, `_make/fetch.tl` and
  their tests landed in stage 1 and are untouched.
- **No entry edited, added, or removed** — twenty in, twenty out,
  byte-identical bodies; the queued patch items land their entries
  AFTER this, in `3p/tl/tl_patch/narrow.tl`.
- **No pin change in this slice** — the pin bump that ENABLES it is
  its own event (the gate below); this diff touches no pin.
- **Frozen**: the 500-line cap (capacity by splitting, decided on
  3ISnTFGe), the anchor contract, the applied-output bytes.
