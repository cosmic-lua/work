Measured from the Actions API rather than inferred, because the shape
was the opposite of the expectation that started the session: the test
gate was assumed slow, and it was never the critical path.

Run 34798623808 (push to main), job start/end relative to run start:

    ci      +4s -> +182s   (gate step 114s)
    build   +4s -> +250s   (build+fixpoint 227s)
    repro   +253s -> +521s (cold rebuild+compare 252s)
    smoke   +253s -> +268s

Run 34798126748 (pull_request) has the same shape: ci at +216s against
a +514s run. Inside the gate, 261s of test CPU finished in 44s wall
after a 70s build, so tests were ~11% of the run and had five minutes
of slack behind them.

An audit of all 356 cosmic test files and 163 internal modules for dead
code and redundant tests found nothing worth deleting: every apparent
dead module was a real convention (init.tl package resolution,
_perf/bench/* discovered by glob, _build/casts_kinds.tl read as data by
path). The only unreferenced symbol was _make/project.tl's unit_label,
filed separately.

Workflow consolidation was evaluated and declined. The container block
is 8 copies across 5 files and only a reusable workflow can hold it,
but calling one renames check runs from `pr / ci` to `pr / ci / <job>`,
which breaks the ruleset's exact-match required contexts. A composite
action cannot declare `container:` and would only absorb the
builder-prep and checkout steps (~30 net lines of 1334), while forcing
edits to _build/workflows_test.tl at 499 of its 500-line cap. Status
quo plus the existing ratchet is the better trade.