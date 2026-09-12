## Change

Implement chunk 1 of Wdaw_QfXv: trustworthy fuzz subprocess results and removal
of invented crash inputs. Repo cosmic-lua/cosmic; baseline
a327ff32760ec15bbde7514c1cd7ed34647ae8d7. Read the parent's frozen architecture,
report protocol, evidence and scope. This chunk is independently safe to land:
until later chunks, crashes report original_input=unavailable and
diagnostic=inconclusive; reason=diagnostic-not-enabled, never reconstructed bytes.

Add optional native `signal: integer` to `_tool/testprocess.tl` Result (line25);
populate it from the reaped child.Result.signal in the final result, including
timeout results, and leave it nil for start errors. Preserve exit_code and all
existing consumers. Classifiers must prioritize timed_out and errors over this
signal. Do not infer a signal from exit_code: exit(143) differs from SIGTERM.

Add `_fuzz/isolation.tl` to own subprocess environment, fresh fs.temp_dir,
testprocess.run, capture classification, and cleanup. API is a typed Request
(argv, name, seed, iters, timeout_ms, diagnostic boolean) and Outcome record
(kind, signal, exit_code, stdout, stderr, detail, checkpoint_bytes). Proposed
kind vocabulary is pass, crash, failure, timeout, infrastructure; use an enum
or string with explicit field invariants. Optional fields use explicit
nil-admitting signatures where functions can return nil. No reference back to
driver from isolation, no import cycle. Later checkpoint decoding belongs to
checkpoint.tl; initial checkpoint_bytes is empty. Expose a pure classify
function accepting testprocess.Result for deterministic unit tests.

Classification order: start_error / cleanup_error -> infrastructure; timeout
-> timeout (include any cleanup error in detail even when kind infrastructure);
native signal -> crash; exit_code=0 -> pass; all other exit codes -> failure.
Report available errors together, never discard timeout evidence. If cleanup
of the temporary directory fails after any result, make the outcome an
infrastructure failure while retaining the observed signal/status in detail.
No parent callback may generate/check inputs. Original launch strips inherited
FUZZ_DIAGNOSTIC_DIR and pins FUZZ_ISOLATE/FUZZ_SEED/FUZZ_ITERS exactly as now.

In `_fuzz/driver.tl` move spawn_isolated's responsibilities to the new helper,
remove bisect_crash and parent gen reconstruction entirely, retain timeout_for
in driver and expose it unchanged. Keep unresolved-interpreter fallback as
currently implemented; this change concerns the isolated path. Keep public
Options/run/run_unisolated shapes and ordinary failure strings. Implement the
parent's original crash, timeout and empty-stderr fallback strings. Update the
module/bisection comments and existing crash self-test to assert unavailable
rather than iteration=5. Driver source currently500 lines; deleting these
mechanisms frees room without moving budget/shrink logic.

Permanent tests: new `_fuzz/isolation_test.tl` tests every classifier branch,
including zero exit with cleanup error, timeout plus supervisor SIGKILL,
empty/nonempty failure stderr, native SIGTERM versus exit143, and missing
interpreter. New `_tool/testprocess_signal_test.tl` runs real children that
raise SIGTERM and exit143 and asserts both signal and preserved exit_code.
Use explicit plain Lua fixture scripts created inside TEST_TMPDIR, run by
proc.interpreter; a fixture need not be a runner-mode test file. Candidate
module under test is imported normally by its outer test. Add no test that
signals the main test runner. Existing driver_test's real hang stays covered.

Focused verification: `bin/cosmic --make test _fuzz/driver_test.tl
_fuzz/isolation_test.tl _tool/testprocess_signal_test.tl`; all new cases must
appear with per-case statuses, then `bin/cosmic --make ci` -> ci: PASS.
Negative controls: deriving signal from exit_code must fail the exit143 test;
restoring parent reconstruction must fail a parent-gen call-count-zero test;
ignoring cleanup_error must fail zero-exit/error classification.

Measured sizing: `wc -l _fuzz/driver.tl _fuzz/driver_test.tl
_tool/testprocess.tl` ->500,499,224; new test files start at0. Locations from
`rg -n 'local function (spawn_isolated|bisect_crash|isolate)' _fuzz/driver.tl`
are283,307,353. Target ~350-400 changed lines including moved code and tests;
do not raise file caps. Keep find_ccov and its existing nil-baseline row in
driver; new helper signatures declare nil honestly, so no baseline additions.

## Non-goals

No diagnostic rerun/checkpoint writing yet, no changes to gen/check call sites,
no new child supervisor, no public process API redesign, no quota/timeouts
increased. Do not migrate or close other board items.
