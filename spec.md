## Change

Implement chunk 3 of Wdaw_QfXv after checkpoint codec and trustworthy isolation:
enable exactly one diagnostic rerun for a natural crash, journal the actual
child's execution, and render the parent's frozen report contract. Repo
cosmic-lua/cosmic. No caller changes to the27 structural driver.run sites.

Modify `_fuzz/isolation.tl` from chunk1: when Request.diagnostic=true, set
FUZZ_DIAGNOSTIC_DIR to that invocation's fresh directory. Before deleting the
directory, read/decode its checkpoint using chunk2's bounded read and carry a
typed result in Outcome (replace the initial checkpoint_bytes placeholder).
Original requests always remove that variable. Checkpoint absence is not an
infrastructure error for ordinary/original runs; it makes diagnosis
inconclusive. Always clean the directory after captures/checkpoint are read,
including malformed records, starts failing, and timeouts. If supervision
reports that reaping failed, retain that failure and make no attribution.

In driver.isolate, launch the original child as now, then only on kind=crash
launch one diagnostic with identical argv/name/seed/iters/timeout_for output.
Keep the original Outcome immutable. Do not recursively call isolate, shrink
the iteration count, call opts.gen/check in parent, or retry a changed signal.
Match the original and diagnostic native signals before considering a
checkpoint. Any diagnostic error/timeout/non-check checkpoint is inconclusive.
Render fields exactly as the parent specifies, including original_input=
unavailable and attribution=last-checkpoint even after a same-signal rerun.
The words 'reproduced' describe a same-signal rerun, not proof of identical
root cause. Exit143 remains an ordinary exit, never a same-signal reproduction.

In driver.run's existing FUZZ_ISOLATE-selected branch only, create an optional
Observer from FUZZ_DIAGNOSTIC_DIR. Define it in new `_fuzz/observe.tl`, which
imports checkpoint/source but never driver. Thread it through run_in_process
using an explicit optional context and closure capture for check/gen wrappers;
no module-global observer. In
each outer iteration bind its index and stage=primary. Wrap gen(rec) with a
generating write before invocation and save #rec.draws after return. Before
attempt(check,input,budget) arm, write checking with actual input and this
count; after attempt disarms, write between. Do not run gen a second time.
Switch stage to shrink before shrink.shrink, supplying the SAME wrapped gen
and a wrapped budgeted check, and to verify before the final replay/gen/check.
All candidate attempts therefore carry the outer iteration and actual
candidate bytes/count, including input-too-large phase. Preserve existing
property exceptions/false returns and shrinking exactly. Journal failures
must latch context.failed and its first error. Once failed, wrapped gen returns
an empty placeholder without calling opts.gen, and wrapped check returns false
plus the latched error without calling opts.check. Check the latch after each
primary attempt, after shrink returns, and before/after final verification;
return an ordinary diagnostic infrastructure failure before any further real
generator/check invocation. Shrink may invoke the wrappers again internally;
the latch prevents real callbacks and all further IO, and the outer failure
takes precedence over shrink's result. Do not throw a journal error through
the property's pcall or treat it as an ordinary counterexample. Add a unit
test injecting a write failure during shrink: no subsequent real gen/check
calls, false result, and journal error instead of a minimized counterexample.
Default Observer=nil skips all encoding/IO.
run_unisolated never enables observation from an ambient environment variable.

Add `_fuzz/diagnostic_test.tl`: a real self-reexec fixture with gen counter
crashes at '5' using SIGTERM. Parent asserts input NQ==, iteration5, draws0,
stageprimary, original_input unavailable, last-checkpoint attribution; child
gen can write its actual input to an independent oracle file for byte equality.
Add a controlled draw-dependent shrink fixture where initial check returns
false and a smaller candidate raises SIGTERM: reported bytes and stage shrink
must match that child's independent oracle. Add same-signal with missing
record, changed-signal, diagnostic clean exit and diagnostic timeout via a
typed injected-launch seam at isolation boundary. Assert original signal
persists and inconclusive results contain no checkpoint_input field. Tests
must observe spawn counts and absence of gen/check calls in parent.

Measured original location sweep is in parent; driver started500 lines and
driver_test499, so use chunk1's extracted module/new tests, not driver_test
growth. Target <400 changed lines; if observer code would take driver above
500, reduce wrapper glue using the already-required `_fuzz/observe.tl` context
without changing the algorithm or state. Keep
find_ccov in driver and new return shapes explicit; no baseline increase.

Run focused driver/isolation/checkpoint/diagnostic tests through --make test,
then full ci: PASS. Negative controls: parent gen reconstruction, second
diagnostic retry, accepting a differing signal, serializing before gen,
missing between/generating stage updates, or skipping observer in shrink must
fail a corresponding test. Do not assert wall-time speedup or byte-only replay
of arbitrary stateful checks. Rerun overhead can change crash timing and an
inconclusive diagnostic is correct, never a passing property.
