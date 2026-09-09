## Evidence

The friction log records repeated local full-gate runs that either failed for host-only reasons or remained silent for more than five minutes. Observed failures include listener permission denial, unsupported assimilation, process/socket differences, timestamp rounding, and localtime wording. Some subprocess suites hung without a bounded progress channel, even after the candidate had been committed and focused tests were green.

This creates two risks: environmental refusal is mistaken for a product regression, and an actual hung test can consume an unbounded builder/reviewer turn. `_tool/testrun.tl` is 391/500 lines and `_tool/testrun_test.tl` is 317/500.

## Change

Give the canonical test runner an explicit bounded-execution and capability-reporting contract.

1. Apply a per-test-file timeout to spawned test processes, with a repository-configurable default and a diagnostic naming the timed-out file, elapsed limit, and captured tail.
2. Distinguish `PASS`, product `FAIL`, environment `UNAVAILABLE`, and timeout in the runner's structured result. An environment classification must come from a declared capability probe, not string matching arbitrary test errors.
3. Define which capabilities the supported Linux CI lane requires and therefore treats as mandatory. Local unsupported hosts may report explicit skips/unavailability, but CI must fail if a required capability is absent.
4. Emit concise phase/state transitions suitable for agent consumption; do not stream a full terminal dashboard on unchanged state.
5. Add hermetic tests for timeout cleanup, output-tail capture, declared capability absence, an ordinary assertion failure, and strict-CI treatment.

Update AGENTS.md's gate guidance to state which local evidence is authoritative and when GitHub Linux CI is the required completion gate.

## Non-goals

No blanket skipping of platform failures, no weakening of Linux CI, and no attempt to make every Cosmopolitan behavior identical on macOS.

## Access

`cosmic-lua/cosmic`, read and write on a branch; no other repository.

## Ready when

Every spawned test file terminates within a declared bound; local unsupported capabilities are reported explicitly rather than as misleading product failures; and the Linux CI lane remains strict for every required capability.
