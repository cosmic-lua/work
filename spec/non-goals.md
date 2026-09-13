- no new enforcement capability: `net` is the R7 slice, gated on the
  cosmopolitan pin; this slice only makes the report able to carry it.
- no change to `landlock.RestrictOptions`, the WRITE/READ masks, or any
  denial — weakening a denial to improve a report is the exact failure
  this epic forbids.
- no change to `fence()`'s policy: an unenforceable host still runs the
  recipe, still unfenced, still only warning when `COSMIC_FENCE` is
  explicitly set. `allow_unenforced` and the broadened warning condition
  in item 8 change what `fence()` can now tell apart (full vs. degraded
  vs. skipped) and what type it reads, never whether it proceeds.
- no changes to `cosmic.quicksand` — its `sandbox.apply` calls in
  `box/run.tl` and the comment in `box/init.tl` are re-confirmed
  unaffected in item 8, not merely carried forward from the prior pass.
