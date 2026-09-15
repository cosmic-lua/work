Research: establish why a CLI subprocess spawned from Teal source pays
a cold compile on every spawn under the gate, when the same spawn hits
the compile cache locally. Deliverable is recorded findings plus the
follow-up item that fixes it — not a code change, because the fix
depends on which cause holds.

Two test files spawn the CLI from source rather than a built binary:
`_work/stateclaim_capacity_test.tl:41`
(`grep -n 'cmd/gitboard/main.tl' _work/stateclaim_capacity_test.tl` ->
`local argv: {string} = {check.must(proc.interpreter()), "cmd/gitboard/main.tl"}`)
and `_work/stateresult_cli_test.tl:29` (same grep ->
`local argv = {runtime, "cmd/gitboard/main.tl"}`).

Answer, with a command and its pasted output for each: does the gate's
sandbox deny writes to the compile cache directory
(`cosmic/_script_cache.tl`'s trusted-directory check, which falls back
to recompiling rather than erroring), or do parallel test processes
race to warm it before any has written? Then file the fix the answer
selects.

Spawn cost, measured with the pinned runtime in a `work` checkout:

    bin/cosmic -e 'print(1)'                        0.013s
    bin/cosmic cmd/gitboard/main.tl help  (cold)    4.566s
    bin/cosmic cmd/gitboard/main.tl help  (warm)    0.075s
    o/bin/gitboard help                             0.017s

CI run 34925846886 per-file wall time against the same two files run
locally with `bin/cosmic --make test`:

    stateclaim_capacity_test   CI 27.545s   local 6.839s   5 spawns
    stateresult_cli_test       CI 10.694s   local 5.886s   3 spawns

CI's 27.5s over 5 spawns is 5.5s each, which is the cold figure, not
one cold plus four warm (~4.8s total). Locally the same file is 6.8s,
consistent with one cold compile and four cache hits. Upper bound if
every spawn were warmed: ~25s of the suite's 1352s test CPU, so ~7s of
wall at 3.6x — small, and worth doing only once the cause is known.
