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
