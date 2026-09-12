## Change

Ship and verify the final runtime pin for buffered HTTP/TLS reuse, completing
`uQsI_Q5CM`. Land in cosmic-lua/cosmic main. The child chain must already contain
accepted upstream fixes and the benchmark/wrapper PR. Wait for the actual cosmos
release built from those commits. Record the merged upstream SHA, release tag,
tag/commit ancestry, SHA256SUMS entry and independently verified archive hash
before editing the pin. No future tag or digest is prescribed by this design.

Update only `3p/cosmos/cosmos_pin.tl`, final availability wording for keep_alive
in `cosmic/fetch/init.tl`, and the end-to-end regression tests needed for the
capability now present. The intermediate wrapper/scenario child already added
the option and instruments; do not duplicate them or change scenario names.
Generate declarations through the normal build, never hand-edit them. Keep
keep_alive false/absent as one-shot; table/stream/proxy exclusions remain.

Existing source anchors at b0ab4e8f: Options is
`cosmic/fetch/init.tl:85` (`local record Options`), and retry classification is
`:254` (`local RETRYABLE_KIND`). Their current semantics are walls, not cleanup
opportunities. `3p/cosmos/cosmos_pin.tl` identifies version and platforms['*'].sha;
its old value during refinement was 2026.09.06-e748d6a1e. Read the current pin
before the change rather than assuming it has not advanced.

Extend `cosmic/fetch/keep_alive_test.tl` with verified TLS same-origin redirects,
same-route retryable HTTP responses and cross-call reuse. Use accept+handshake
counts to prove resource reuse, and per-request body/sequence assertions to prove
correct responses. Keep malformed framing, route/policy and no-hidden-retry
proofs in the C gate. Run active stream and buffered calls together; stream close
or GC must not corrupt the pool. Verify false/absent default behavior explicitly.

Verification commands from cosmic root:
1. `bin/cosmic --make fetch`
2. `bin/cosmic --make ci` ending `ci: PASS`; require the project's Linux lane
   and macOS/Windows smoke evidence for the built artifact, not skipped local cases.
3. With explicit unmodified/candidate BIN paths and distinct measured hashes,
   run the optimize skill's baseline/current full `_perf/run.tl` over the SAME
   harness, then `_perf/gate.tl compare BASE CURRENT SELFB`. `SELFB` is a fresh
   output path, never BASE. Require `perf-compare: PASS` and a noise-qualified
   sequential TLS gain; use the documented interleaved procedure if below the bar.

The PR evidence names both cosmic and cosmos commits, hashes, build modes,
all correctness verdicts, old/new accepts+handshakes, and actual scenario values.
No claimed speedup before measuring; no weakened check or renamed scenario to
obtain PASS. One local green run cannot substitute for mandatory platform lanes.
If the end-to-end pin shows a surviving regression, do not ship it: retain the
old pin, record the measurements on the board and file the bounded blocker.

After acceptance/landing, verify the parent design's matrix is accounted for by
permanent tests across the child PRs, and record that final landed commit as the
parent's evidence. Do not implement the parent again. No source implementation
was performed by the refinement that created this chain.

## Access

Read cosmic-lua/cosmic for wrappers, benchmarks, pins and skills; read
cosmic-lua/cosmopolitan for transport sources, native tests and release evidence;
read cosmic-lua/work for the parent design and prerequisite evidence, supplied
by the orchestrator in the builder brief. The implementation PR targets only
the repository assigned to this item; agents do not mutate the board.
