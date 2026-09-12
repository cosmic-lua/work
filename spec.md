## Change

Replace crash bisection and parent-side input reconstruction in `_fuzz/driver.tl`
with truthful process classification and at most ONE diagnostic rerun. The rerun
records the actual child's most recent execution checkpoint. It may reproduce
the original signal, fail differently, or be inconclusive; it can never turn
the original failure into success. Do not claim the rerun observed the original
process's bytes, that a seed controls process-global state, or that a checkpoint
proves which instruction caused a signal.

This is an implementation design, refined against cosmic main
a327ff32760ec15bbde7514c1cd7ed34647ae8d7 on 2026-09-12. No product code was
changed. Implement the four child chunks in dependency order. All PRs land in
cosmic-lua/cosmic. Preserve this item's existing priority and parent.

Implementation order (the board's child edges encode these dependencies):

1. SzFj_aL8o — trustworthy process results and no invented crash input.
2. AIK2_Q8tc — bounded versioned child checkpoint codec.
3. 7ZdI_XhPV — record actual child inputs in one bounded crash rerun.
4. hpiM_hXJI — adversarial integration and full verification.

Each item contains concrete files, behavior, failure cases, permanent tests,
negative controls, scope, and verification commands. Later chunks may only
land after their prerequisites; no concurrency on driver.tl is intended.

### Fixed architecture

1. Extract process ownership/classification into `_fuzz/isolation.tl`. Reuse
   `_tool/testprocess.tl`'s file-backed, monotonic, process-group supervisor;
   add an optional native `signal` field to its Result, retaining every existing
   field/exit_code convention. Never infer a signal from exit_code >= 128.
   Setup/capture/wait/cleanup errors and timeouts are failures, including errors
   accompanying exit_code=0. Reaping after timeout does not make SIGTERM or
   SIGKILL an application crash. Use a fresh fs.temp_dir() for each subprocess;
   remove it only after the supervisor has finished and the parent read its
   captures/checkpoint. Cleanup failure remains a reported failure. Do not
   write a second process supervisor or rely on GC to stop a timed-out child.
2. Remove bisect_crash. On an original natural signal without supervision
   error, re-exec the SAME interpreter/script with the same property, seed,
   iteration count, Options/budget behavior, and one fresh diagnostic directory.
   Preserve the original full iteration prefix and shrinking order: generators
   and checks can maintain process-local state. Do not call gen/check in the
   parent. Each subprocess gets timeout_for(opts,iters), including an absolute
   explicit timeout. No recursive diagnostics, bisection, adaptive retries, or
   further spawn on an inconclusive result. Healthy runs have one subprocess;
   an original crash has at most two. Initial timeout/start/error/ordinary
   failure does not trigger a diagnostic. Diagnostic failure never replaces the
   original signal. This bounds added work to one supervised timeout allowance
   (plus the supervisor's existing cleanup grace), not log2(iters) allowances.
3. `_fuzz/checkpoint.tl` owns a versioned binary record and atomic file writes.
   Only the diagnostic child records. The parent sets private
   FUZZ_DIAGNOSTIC_DIR in that child's environment; the original subprocess
   environment removes any inherited value. Read it only in the selected
   FUZZ_ISOLATE branch. It is an internal protocol, not a public flag. The
   unrelated ambient FUZZ_ISOLATE authentication problem stays with fhob_GDAm.
4. Instrument the existing loop without adding generator/check calls: publish
   generating before each generator call, checking with its actual returned
   bytes and consumed draw count before each attempt, and between after each
   attempt. Wrap shrink's generator and budgeted check too, then its final
   verification. Retain the outer iteration and stage primary/shrink/verify.
   Journal failures abort diagnosis with an ordinary nonzero failure; never
   continue after a write failure. Original execution and run_unisolated keep
   their existing behavior. Observer callbacks run outside the VM budget hook;
   existing arm/disarm and collector coexistence must remain intact.

### Checkpoint protocol (frozen for all children)

One file `<fresh-diagnostic-dir>/checkpoint`, written with
fs.write(path, bytes, {atomic=true, mode=fs.octal("600")}). Existing temp_dir
uses mkdtemp; no predictable global paths and no stdout/stderr markers. File
capture cannot be confused by arbitrary property output. A local corrupt
record is data to reject, never code to evaluate.

Header is Lua string.pack format `>c8i8i8i8I1I1i8I4`, followed by raw input
bytes. Fields: magic `CFUZZ001`, seed, configured iters, outer iteration,
phase, stage, consumed draws, input length. Header is 46 bytes (executed
`cosmic -e 'print(string.packsize(">c8i8i8i8I1I1i8I4"))'` printed `46`). phase values
1=generating, 2=checking, 3=between, 4=input_too_large; stage values
1=primary, 2=shrink, 3=verify. Seed is any signed Lua integer; iters positive;
iteration in 1..iters; draws nonnegative. Generating/between carry draws=0,
length=0. checking carries the actual byte string including NUL/non-UTF-8 and
its length; zero bytes IS a valid observed input. Maximum stored input is
1,048,576 bytes. Larger inputs publish phase=4 with no payload and draw count
zero, still run the check, then publish between. Do not truncate or constrain
what the property itself accepts. Decode requires exact length, magic, numeric
ranges, known phase/stage, and expected seed/iters; reject trailing bytes,
truncation and length overflow. Read at most header+cap+1 bytes through fd,
then reject excess; do not allocate from an untrusted advertised length.
Open with fd.O_RDONLY|fd.O_NONBLOCK|fd.O_NOFOLLOW, then fs.stat_fd(h:fd())
must report is_file() before reading. Reject a FIFO/device/directory/link
without waiting, closing the handle on all branches. This closes the gap
between bounded byte count and bounded opening/reading of a replaced path.
Measured at implementation intake: a mkfifo fixture opened with these flags
printed `opened without waiting; is_file=false` on the pinned Mac runtime.
Use pcall around pack/unpack, no load, JSON or literal evaluator. Return
explicit records with valid/error fields, not nil-shaped success tuples.

Atomic rename plus a fresh directory prevents a partial/new run from being
mistaken for a complete previous checkpoint. It does NOT make checkpoint and
check execution atomic. Therefore even a valid checking record means only
"last checkpoint before a check in the diagnostic process". A signal can
arrive immediately before/after that call; report context, not proven causation.
There is no promise of crash attribution for a signal in the generator,
journaling, VM internals, or memory corrupted during an earlier check.

### Report contract

Keep run/run_unisolated -> boolean,string; keep ordinary success, property
failure/shrink, instruction-budget strings and Options fields. driver.Options
and driver.timeout_for remain reachable at their current names. Change only
crash/infrastructure/timeout diagnostics that currently invent a location.

- Original crash always starts `<name>: seed=N configured_iters=N: crashed:
  signal S; original_input=unavailable`. Do not print the legacy numeric
  `iteration=iters`, `input(base64)=`, or `draws=0` as an invented observation.
- A same-signal diagnostic with a valid checking checkpoint and no supervisor
  errors appends `; diagnostic=reproduced; checkpoint_iteration=I;
  checkpoint_stage=primary|shrink|verify; checkpoint_input(base64)=B;
  checkpoint_draws=D; attribution=last-checkpoint`. These fields describe the
  rerun, never the original process. Empty B is a real empty string only here.
- Otherwise append `; diagnostic=inconclusive; reason=<reason>` and no input
  field. Distinguish clean exit, ordinary failure, changed signal, timeout,
  setup/wait/capture/cleanup error, missing/malformed record, non-check phase,
  oversized input. Include diagnostic signal separately when it differs.
- Initial timeout retains `hung: exceeded Nms`, but uses configured_iters
  and `input=unavailable` rather than an invented failing iteration. Other
  infrastructure failures have nonempty `isolation failed: <reason>` text.
- Initial ordinary nonzero exit forwards nonempty stderr as today; if stderr
  is empty, supply `isolation failed: child exited CODE without a diagnostic`.

### Verification in the implementation diffs

Every child adds permanent runner-mode tests; focused commands and expected
invariants are in each child spec. Full repository acceptance remains
`bin/cosmic --make ci` -> `ci: PASS`, followed by independent review. No
standalone `_test.tl` invocation as proof: runner-mode bare scripts may do
nothing. Run real subprocess tests under the normal test gate and coverage.
Retain FUZZ_ITERS=50000 coverage in the existing fuzz workflow; do not enlarge
workflow timeouts, weaken properties, or modify benchmark thresholds.

Mandatory final tests cover true signal versus ordinary exit(128+signal),
stateful generators, parent-generator call count zero, shrinking checkpoints,
malformed/stale/oversized checkpoints, missing checkpoint, changed signal,
timeouts and error precedence, empty stderr, sibling properties and temporary
environment restoration, repeated failure cleanup, and passing runs creating
no input checkpoints. Assert subprocess count (one healthy, at most two on a
crash). A same-process/sham-spawn classifier test complements real child tests;
it must not be the sole verification. Expected-failure children must be caught
by the fixture parent and asserted, not exempted from CI.

### Measured source inventory and evidence

`git ls-remote origin refs/heads/main` printed
`a327ff32760ec15bbde7514c1cd7ed34647ae8d7 refs/heads/main`.
`wc -l _fuzz/{driver,driver_test,source,shrink}.tl _tool/testprocess.tl`
printed 500,499,108,237,224. Neither driver file has room to grow: extract
isolation, put new tests in new files, do not raise the 500-line cap.

`bin/cosmic --find 'driver.run($$$ARGS)' _fuzz` printed
`find: 27 hit(s) in 12 file(s)` (including driver self-tests); no property
call sites need API migration. `rg -n 'local function
(attempt|failure|run_in_process|spawn_isolated|bisect_crash|timeout_for|isolate|run)'
_fuzz/driver.tl` locates attempt167, failure215, run_in_process247,
spawn_isolated283, bisect_crash307, timeout_for332, isolate353,
run_unisolated397, run414. `rg -n 'local record Result|local function
(run|exit_code)' _tool/testprocess.tl` gives Result25, exit_code96, run106.
These are locations at the named head, not promises of future line numbers.

Current timeout_for already returns max(30000,iters*10), with explicit
timeout_ms absolute. The old capture's fixed-30-second claim is stale: do not
reimplement scaling. `cosmic.child.Handle:wait` explicitly leaves a timed-out
handle usable; driver.spawn_isolated currently drops it. Reusing testprocess
avoids inventing a new cleanup implementation. Source inference, not a new
measurement of the maximum scheduling latency: its polling/TERM/KILL constants
are 10/250/1000ms, and it records failed reaping instead of blocking forever.

Executed source-transpilation probes on macOS arm64 with pinned Cosmic
2026-09-10-851d5ec (SHA256
10f66af3cfe6b55e3f97c058ddff5e6b0ba3faf6eef8c2462cb7372895e4e1c2).
A child.start/proc.interpreter test double, loading freshly transpiled
driver.tl, returned these sequences (initial child plus bisection children):

```
signal11, exit0, signal11, signal11:
counter ok=false spawns=4 parent_gen_calls=1
counter: seed=1 iteration=5 input(base64)=MQ== draws=0: crashed: signal 11
signal11, timeout, exit0, exit0:
timeout_probe ok=false spawns=4 parent_gen_calls=1
timeout_probe: seed=1 iteration=8 input(base64)=MQ== draws=0: crashed: signal 11
signal11, start-error, exit0, exit0:
start_error_probe ok=false spawns=4 parent_gen_calls=1
start_error_probe: seed=1 iteration=8 input(base64)=MQ== draws=0: crashed: signal 11
{code=0,ok=false,io_error='injected pipe failure'}:
io_error ok=true spawns=1 parent_gen_calls=0
io_error: 8 iterations, seed=1
```

Real process corroboration used the merged PR1837 Cosmic artifact SHA256
26b019456bfd33bfa8e5624fd957353e8db7411a67a4a23836d5ff9ce1d7a313 and
the freshly transpiled current driver. Eight iterations; gen increments a
process-local counter and returns tostring(counter); check raises SIGTERM
only for input='5'. Output and exit status:

```
false  real_counter: seed=1 iteration=5 input(base64)=MQ== draws=0: crashed: signal 15
exit status 1
```

MQ== is '1'; the actual signal-triggering value was '5' (NQ==). This is a
controlled process signal, not a C memory-corruption exploit. Reproduce from
a repo checkout by compiling driver to /tmp/fuzz-driver-probe.lua, then running
this explicitly invoked ordinary Lua script using a runnable Cosmic artifact:

```lua
local driver = assert(loadfile('/tmp/fuzz-driver-probe.lua'))()
local signal, env = require('cosmic.signal'), require('cosmic.env')
local counter = 0
local ok, msg = driver.run({name='real_counter', iters=8,
  gen=function() counter=counter+1; return tostring(counter) end,
  check=function(input)
    if input=='5' then assert(signal.raise(signal.SIGTERM)) end
    return true
  end})
if not env.get('FUZZ_ISOLATE') then print(tostring(ok), msg) end
if not ok then os.exit(1) end
```

Compile command: `bin/cosmic --compile _fuzz/driver.tl >
/tmp/fuzz-driver-probe.lua`. Save script to /tmp/fuzz-real-probe.lua and run
`bin/cosmic /tmp/fuzz-real-probe.lua` from the checkout. Where an APE binary
needs its shell launcher, use `sh <artifact> /tmp/fuzz-real-probe.lua`.
The fake supervisor sequences above specify permanent classifier regression
inputs; the local refinement probe files are convenience evidence, not an
implementation dependency.

### Ratchets and scope

Add only internal `_fuzz` modules/tests plus the additive testprocess Result
field and its tests. No new public API, C binding, CLI flag, dependency pin,
tracked data format migration, or corpus persistence. Declare nil-admitting
returns explicitly in new helpers, use typed records/test seams, and introduce
no unclassified casts. `_build/nil_returns_baseline.tl` currently has
['_fuzz/driver.tl']=1 for find_ccov's implicit nil; leave find_ccov in driver
so this row stays 1. Do not rebaseline unrelated counts. New internal files
are enrolled by the source tree; tests defining test_* enroll automatically.
Any fixture read/copied by path declares `--- reads: <fixture-path>` before
its first local. Fixtures must use the candidate-built module closure, not a
pin's embedded _fuzz module. The driver_test headroom sibling eDS8_niuS stays
open for its own reconciliation; this plan needs no separate preparatory PR.

## Non-goals

Do not require pure generators, promise byte-only replay restores arbitrary
closure state, or repair the ordinary shrinker's impure-generator semantics.
Do not persist a corpus, add fuzz guidance, authenticate ambient FUZZ_ISOLATE,
change process APIs beyond preserving the signal, implement shared memory
across exec, or journal every passing run. Full original-input recording
would require always-on IPC/storage and a separate measured design. Bisection
is rejected because crash/no-crash is not monotonic for stateful/nondeterministic
or timed-out executions; no amount of parent-side reseeding repairs that.
No speedup is claimed for this design. Diagnosis may fail to reproduce due to
changed timing or state; honest unavailability is the required result.
