- **`_fuzz/shrink.tl` is not touched.** `still_fails` keeps accepting a
  candidate on ANY failure; making shrinking preserve the failure KIND
  is a different design with a different cost, and this item's fix makes
  it unnecessary for the message to be honest.
- **`failure()` does not move.** Its signature, its
  `seed=/iteration=/input(base64)=/draws=` grammar and the
  `budget=%d exceeded` and `threw: ` texts are unchanged;
  `driver_test.tl` asserts substrings of all of them and
  `.github/workflows/fuzz.yml` documents them.
- **`iteration=` still names the ORIGINAL iteration.** Only the detail
  and the draw count move to the minimized input; the iteration index is
  what makes a failure replayable with `FUZZ_SEED`.
- **Not the wall clock, not the budget's size.** `DEFAULT_TIMEOUT_MS`,
  `TIMEOUT_PER_ITER_MS`, `timeout_for`, `DEFAULT_BUDGET` and
  `BUDGET_MESSAGE` are unchanged, and `opts.gen` stays outside the
  budget.
- **`source.new`'s Recorder is unchanged.** Only `replay`'s `draws`
  semantics move; the recording wrapper already reports exactly what it
  drew.
- **No new module.** The 500-line cap is not near binding on either file
  after this change (measured below), so nothing is split out.
- **No `.cosmic-coverage` regeneration is expected** — no file is added
  and all three already carry a row. If the ratchet does complain, run
  exactly the regen command its failure message prints
  (`bin/cosmic --make coverage --baseline`) and commit the result; never
  weaken the gate any other way.
