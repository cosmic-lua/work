Give the canonical test runner an explicit bounded-execution and capability-reporting contract.

1. Apply a per-test-file timeout to spawned test processes, with a repository-configurable default and a diagnostic naming the timed-out file, elapsed limit, and captured tail.
2. Distinguish `PASS`, product `FAIL`, environment `UNAVAILABLE`, and timeout in the runner's structured result. An environment classification must come from a declared capability probe, not string matching arbitrary test errors.
3. Define which capabilities the supported Linux CI lane requires and therefore treats as mandatory. Local unsupported hosts may report explicit skips/unavailability, but CI must fail if a required capability is absent.
4. Emit concise phase/state transitions suitable for agent consumption; do not stream a full terminal dashboard on unchanged state.
5. Add hermetic tests for timeout cleanup, output-tail capture, declared capability absence, an ordinary assertion failure, and strict-CI treatment.

Update AGENTS.md's gate guidance to state which local evidence is authoritative and when GitHub Linux CI is the required completion gate.
