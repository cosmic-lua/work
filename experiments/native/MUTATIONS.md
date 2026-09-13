# Native semantic mutation checks — 2026-09-13

The initial campaigns killed **12 claim/transaction/read mutants and 3 bounded-policy
mutants**. Both campaigns had zero surviving, invalid, or non-assertion-error
mutants. Every target test passed before mutation and again after restoring the
original source. These reports precede the second-review fixes. The expanded
15-case main and 7-case bounded/retry catalogs are ready; their final runs will
use the published follow-up checkpoint without source overlays.

| Campaign | Killed | Results | Exact source and substitutions |
| --- | ---: | --- | --- |
| Claim, transaction, and canonical read | 12/12 | [Literal results](claim-transaction-results.literal) | [Provenance](claim-transaction-provenance.literal) |
| Bounded workload policy | 3/3 | [Literal results](bounded-results.literal) | [Provenance](bounded-provenance.literal) |

The separate migration campaign reports 12 kills through
[`migration_mutations.tl`](migration_mutations.tl); those are not
included in the 12+3 counts above.

## Method and scope

[`mutation_check.tl`](mutation_check.tl) creates an isolated Git worktree at the
recorded revision, applies explicitly named source overlays, and preserves the
complete `_work` snapshot with its evidence. These runs used
`0e3701fd93076d7f174f408a08d6a2a45086e2c1`; the provenance literals record their
individual overlays and exact substitutions. The shared checkout was never
mutated by the runner, and no live board or remote was used.

For each mutant the runner requires strict type checking, runs the real test
compilation/discovery pipeline, then executes the generated Lua and module
manifest under a new native test-output prefix. A fresh assertion failure is a
kill. Compile/discovery failures are invalid mutants, and failures without an
assertion trace are errors. Cached test verdicts never establish a kill.

The 12 sentinels cover expired claims, stale-store authority, acquisition identity
on renewal and reacquisition, first-parent receipt ancestry, claim read fences,
final connector/local deadline boundaries, immutable frozen transactions,
complete transition-chain receipts, and canonical remote reads. The three bounded
sentinels cover commit/research handovers in the doing count, whole-batch projected
workload, and excluding containers from workable-leaf workload.

An initial tip-only receipt mutant survived because the older squash regression
also changed final-transition metadata. The new
[`stateplan_receipts_test.tl`](../../_work/stateplan_receipts_test.tl) preserves the
exact final tree, diff, logical author, and message while substituting an earlier
first-parent operation; this independently killed the mutant in the final run.
An initial bounded predicate mutation failed strict compilation after leaving an
unused variable. It was corrected to the same faulty predicate while retaining
the variable reference, then killed by a real workload assertion. Neither initial
result was counted as a kill.

## Reproduction

With the referenced changes present in the checkout:

```sh
bin/cosmic experiments/native/mutation_check.tl experiments/native/mutations.tl \
  _work/stateclaim_authority.tl _work/stateclaim_authority_test.tl \
  _work/stateplan_receipts_test.tl

bin/cosmic experiments/native/mutation_check.tl experiments/native/bounded-mutations.tl \
  _work/graphguards.tl _work/stategate.tl _work/stategate_test.tl
```

Each run writes `results.literal`, `provenance.literal`, the frozen source snapshot,
strict-compilation logs, and baseline/mutant/restored fresh-execution logs under
`o/native-state-mutations/<run>/`. The completed runs were
`J4OLkAfpXfdVR7bAxv2zrrol6tuaHZ13` and
`ywPJ1kpvoCKsspb0ch7PWq4459mPlzvk`, respectively. The runner/catalog were consolidated
from `experiments/native-state` into this directory after those executions;
recorded provenance retains the paths used at execution time.
