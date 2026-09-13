- No change to `failure()`'s signature or its message shape for a
  GENERATED-input failure. Only replay's report is new ground, and it
  uses its own separate formatter.
- No automatic corpus pruning or deduplication in this item. Content-
  addressed filenames already dedupe by BYTES, so the growth surface
  is "distinct minimized bugs", not "re-triggers of the same one".
- Not a rewrite of the six existing `*_fuzz_test.tl` properties. No
  existing property changes and no committed `_fuzz/testdata/` files
  are added by this item.
- No default-on write path. `FUZZ_SAVE` stays opt-in.
- **Not this item — crash-regression attribution for corpus entries.**
  A corpus entry that C-crashes when replayed reports through the
  existing generated-iteration bisection (`isolate()` / `bisect_crash`),
  which will misattribute it to `iteration=1` with a fresh input.
  Filed as its own follow-up under 3I1j7yQA. This item's tests all
  use `run_unisolated` so the deferral does not gate its Acceptance.
- No timing/quota on the corpus loop separate from the generated loop.
  Per-file budget is the same VM-instruction budget the generated loop
  uses; the wall-clock cap is the child's `timeout_ms` as a whole.
- The `.cosmic-coverage` rows for the two new modules ARE part of this
  item's diff, regenerated with `bin/cosmic --make coverage --baseline`
  and committed with the code. This is not optional and not a separable
  concern: `_fuzz/**` is covered (the floor carries `_fuzz/driver.tl`,
  `_fuzz/shrink.tl`, `_fuzz/source.tl`), and the ratchet's file-set
  drift check fails a source file that has coverage data and no row.
  The last attempt (PR #1297) was right to include it.
