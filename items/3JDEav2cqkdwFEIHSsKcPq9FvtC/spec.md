## Change

Independently verify the landed dependency-projection optimization against
parent W2CS_hqfO's correctness and performance contracts. This is the last
child; the nested tests, benchmark, and implementation children must be
complete. Produce evidence on the board; no new feature or tuning change.

## Access

cosmic-lua/cosmic (main), cosmic-lua/work. Obtain the immutable baseline
binary and report files from the benchmark child, or rebuild that exact
benchmark-only commit with the recorded runtime/package configuration.
Never substitute a stock release or infer binary identity from --version.

## Verification

Review source for exact root exclusion, ordinal order, correct dense
fallback, single-slot identity invalidation, fresh result ownership, and
no unbounded caches. Run the exact contract/oracle and existing integration
tests through the runner, then candidate --make ci. Demonstrate transitive
edit invalidation, unrelated edit isolation, declaration dependency
tracking, unchanged facts, and unchanged test grant membership/order.
Inspect the built artifact's embedded _make/deps code to confirm it
contains the change and each benchmark child actually uses that artifact.

Using identical benchmark files and explicit binary paths/PERF_BIN,
run full baseline and candidate `_perf/run.tl` through --make run, keeping
distinct output paths. Run `_perf/gate.tl compare BASE CURRENT SELFB` and
record its exit status and `perf-compare: PASS` line. Quote sparse, dense,
first-sweep and single-root rows, baseline/candidate spreads, allocation
figures and binary SHA256s. Repeat the current-tree diagnostic separating
scan, first sweep and warm sweeps on both binaries; never equate the
historical 944-file workload with today's tree. For small effects follow
the skill's interleaving/cross-session rules instead of claiming success
from one low-noise session. Investigate surviving flags by the optimize
skill's prescribed procedure, not repeated runs until green.

## Acceptance

Only mark complete after all exact behavior checks pass, the sparse target
improves beyond noise, and the full gate passes without an unexplained
dense/cold/single-root regression. Otherwise record failure/uncertainty
and leave the outcome unverified; a regression requires a focused repair
or revert before completion. Archive raw measurements as local artifacts
and the durable findings on the board. No performance docs in the product
repo and no C release/runtime pin bump. Report candidate commit, runtime
pin, binary hash, test commands, verdicts and target deltas so another
agent can reproduce the conclusion.
