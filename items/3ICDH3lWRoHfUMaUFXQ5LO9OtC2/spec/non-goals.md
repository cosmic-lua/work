- **`_fuzz/shrink.tl` is not touched.** No new parameter on
  `shrink.shrink`, no arm/disarm callbacks threaded through it, no new
  leaf module for the hook. The four `shrink_test.tl` call sites stay
  as they are.
- **`MAX_SHRINK_ATTEMPTS` is not changed**, and no per-candidate
  wall-clock bound is added. The VM instruction budget is the only
  mechanism this item touches.
- **The failure message's shape does not move.** `failure()`'s
  signature, the `"budget=%d exceeded"` text and the
  `seed=/iteration=/input(base64)=/draws=` grammar are unchanged;
  `driver_test.tl` asserts substrings of all of them.
- **Not the minimized-input/detail pairing.** A shrunk run still
  reports the ORIGINAL iteration's detail and the minimized input's
  draw count. That mismatch is item 3ICDHHW7 and must not be fixed
  here.
- **Not the wall-clock backstop.** Item 3ICDGiWd (PR #1309) owns the
  child timeout; this diff must not touch `DEFAULT_TIMEOUT_MS`,
  `TIMEOUT_PER_ITER_MS` or `timeout_for`.
- **`opts.gen` stays outside the budget**, as it is today.
- **No `.cosmic-coverage` regeneration is expected.** Both files
  already carry a row and no file is added. If the ratchet does
  complain, run exactly the regen command its failure message prints
  (`bin/cosmic --make coverage --baseline`) and commit the result —
  never weaken the gate any other way.
