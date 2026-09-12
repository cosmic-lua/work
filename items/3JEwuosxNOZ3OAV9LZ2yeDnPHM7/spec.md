## Change

Correct the item 3 diagnostic test environment after exact-head Linux fuzz CI exposed an inherited iteration-count failure. Repo cosmic-lua/cosmic. Base the repair on item 3 commit `a16a539de34b34a41f8605ac6340bf0fe301f591`; change only `_fuzz/diagnostic_test.tl`.

The test helper `with_selected` simulates the selected child by setting `FUZZ_ISOLATE` and `FUZZ_DIAGNOSTIC_DIR`, but leaves ambient `FUZZ_ITERS` untouched. The pull-request fuzz workflow exports `FUZZ_ITERS=2000`, so `test_observer_orders_every_primary_phase_and_unisolated_ignores_ambient` executes 2,000 iterations and fails its exact one-iteration phase sequence. Production selected children correctly honor the parent's pinned `FUZZ_ITERS`; do not change driver precedence or weaken the assertion.

Make the fixture pin `FUZZ_ITERS=1` for its simulated child execution and restore the prior value on exit, alongside its existing restoration of `FUZZ_ISOLATE` and `FUZZ_DIAGNOSTIC_DIR`. Preserve a real ambient value, and unset the variable when it was initially absent. Keep cleanup explicit and scoped to the fixture. If a small helper is needed to make restoration reliable, keep it in this test file; no production edits.

Verification: `FUZZ_ITERS=2000 bin/cosmic --make test _fuzz/diagnostic_test.tl` passes all five cases, the combined driver/isolation/checkpoint/diagnostic focused suite passes 51/51, and exact-head PR and fuzz workflows pass on Linux. Add or adjust an assertion proving the caller's ambient `FUZZ_ITERS` value is restored after the helper. Negative control: omit the pin or restoration and show the corresponding phase-order/restoration assertion fail. Touched-file type/fmt/lint and focused coverage must pass. Fresh Sol review must inspect the final combined head; do not rely on item 3's earlier acceptance for the corrected commit.

Evidence: fuzz workflow run 34712625719, job 103604030848 failed `_fuzz/diagnostic_test.tl:157`, expected one `write1,gen,write2,check,write3` sequence and observed 2,000. The production tests and platform smoke checks otherwise passed. This is a correction for the accepted item 3 change, not a change to feature semantics.
