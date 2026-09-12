## Change

Implement chunk 4 of Wdaw_QfXv after integrated diagnostics: commit adversarial
end-to-end regression tests and accurate driver documentation; verify the
complete feature through the repo gate. Repo cosmic-lua/cosmic. Parent freezes
protocol, field names, limits and non-goals. No new product mechanism here.

Add `_fuzz/diagnostic_edges_test.tl` and, only if needed for line caps,
`_fuzz/diagnostic_cleanup_test.tl`. Use candidate-built imports and explicit
plain Lua child scripts in TEST_TMPDIR. Check outputs by fields and exact
byte/base64 equality, not broad 'crashed' substrings. Reuse typed test seams
from earlier chunks for impossible/reliably unportable OS failures, alongside
real children for success, signal, timeout and stateful generation. If committed
fixture files are read/copied, declare exact paths with reads headers.

Required regression matrix:

1. Genuine SIGTERM versus exit143, zero exit plus supervisor/capture error,
   failure with empty stderr, original start error: failure is always false,
   no invented numeric iteration/input and a nonempty explanation.
2. Initial hang -> one child; actual timeout_ms stays absolute. Diagnostic
   hang -> at most two children, original signal retained, timeout reason.
   Assert bounded supervisor cleanup and reap using existing testprocess
   conventions, with generous scheduler tolerance; never a sleep-only guess.
3. Stateful counter and a check that also mutates generator-visible state:
   diagnostic replays the whole prefix without adding calls; reported bytes
   equal child's independent checkpoint oracle. Parent invocation count0.
   A deterministic file-backed switch makes the rerun differ from original;
   clean exit/different signal then means inconclusive, not a fabricated input.
4. Crashes during gen, shrinking gen, checking a shrink candidate and final
   verification: only actual checking checkpoints can supply input; stage
   and outer iteration are correct. A checkpoint records context, not causal
   certainty, and reports attribution=last-checkpoint in every success case.
5. Missing, partial, stale seed/iters, unknown version, trailing payload and
   oversized record -> no input field. Real empty input -> empty base64 WITH
   a valid checkpoint marker. Malformed data cannot throw the parent process.
6. Multiple properties in one file: only selected child observes; sibling
   skips do not write its record. Restore FUZZ_SEED/FUZZ_ITERS/FUZZ_ISOLATE and
   new diagnostic variable after each environment-mutating test. Original
   launch strips inherited FUZZ_DIAGNOSTIC_DIR; it cannot overwrite an ambient
   sentinel. This does not claim to solve the separate FUZZ_ISOLATE bypass.
7. Several sequential crashes/timeouts/successes use distinct fresh directories;
   no old checkpoint reused, no surviving direct child after successful reap,
   no temp captures/record left after successful cleanup. Inject cleanup
   failure and assert it cannot become a pass or a reproduced input.
8. Healthy run spawns once, invokes the original expected number of gen/check
   calls, writes no input journal, and retains ordinary success text. Crash
   path launches at most once more regardless of iters. Assert with a typed
   launch observer, not an unstable elapsed-time threshold.

Update `_fuzz/driver.tl` header/doc comments to state diagnostic rerun and
seed limitations accurately. Remove claims that bisection reports the original
input. Sweep `rg -n 'bisect|bisection|crashed: signal|hung: exceeded|every
failure is replayable' _fuzz` and fix only descriptions/assertions of this
mechanism. Record sweep results in PR; matches in intentional historical or
negative-test prose are fine and must be explained. No broad docs rewrite.

Verification: focused `_fuzz` tests via `bin/cosmic --make test _fuzz`, full
`bin/cosmic --make ci` -> ci: PASS, and existing deep-fuzz lane at
FUZZ_ITERS=50000 with recorded seed. Keep produced diagnostics in CI artifacts
or PR evidence; do not commit o/ outputs. Passing deep fuzz is a smoke check,
not evidence that the fault fixtures ran: include their per-case statuses.
Run existing Linux gate/coverage and available macOS smoke against the built
artifact; do not claim Windows signal/process-group coverage without a real
run. Unsupported facilities use existing explicit capability skips, never
catch-all passing assertions. No C changes or release pin work needed.

Budget ~250-350 new test/documentation lines, split files below500. Source
inventory at the parent's head: driver500, driver_test499, testprocess224;
do not consume driver_test's nonexistent headroom. New helpers/tests use
honest typed records and no unclassified casts, preserving the single
find_ccov nil-baseline row. Final independent review must check all four
chunks together against the parent protocol, especially signal-vs-exit,
error precedence, observer placement outside budget hook, and stale-record
rejection. Completing this child completes the feature's proof, not the
broader cosmic.fuzz publishing outcome.
