- No other cast-removal wave from the epic's plan (waves 1-7, or the `_eval`/`_fuzz`
  ratchet-hole fix in wave 7) is touched in this slice. In particular, do not touch
  `cosmic/time.tl`'s own 7 casts (unrelated `binding-boundary`/`from any` sites, a
  later wave) — only `cosmic/time_test.tl` is in scope.
- No new `is` guards are introduced anywhere in either file. This slice is deletion
  only: call the now-typed API directly, or (for the one surviving probe) keep the
  `{string: any}` escape hatch as-is. Do not replace the survivor with an `is` check —
  the whole point of `test_mkstemp_is_gone` / `test_is_accessible` /
  `test_retired_aliases_are_gone` is that the probed names are ABSENT from the typed
  record, so there is nothing for `is` to narrow.
- The coverage floor (`.cosmic-coverage`) is not touched and needs no regen: it holds
  zero `_test.tl` rows (see facts), so deleting test-file casts changes no covered-line
  count the ratchet tracks.
- No behavioral change to any test's assertions. Every `assert(...)` in both files
  keeps checking exactly what it checks today; only how the value under test is reached
  changes (typed call vs. cast-through-`any`).
