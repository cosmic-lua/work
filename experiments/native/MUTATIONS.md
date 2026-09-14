# Native semantic mutation checks — 2026-09-14

The six campaigns killed **70/70 mutants**. All passed their unmodified and
restored controls, with zero surviving, invalid, or non-assertion-error mutants.
Reports identify the exact tested sources rather than implying one run at a
later documentation commit.

| Campaign | Killed | Results | Exact source and substitutions |
| --- | ---: | --- | --- |
| Claim, transaction, and canonical read | 18/18 | [Literal results](claim-transaction-results.literal) | [Provenance](claim-transaction-provenance.literal) |
| Bounded replay and membership | 15/15 | [Literal results](bounded-results.literal) | [Provenance](bounded-provenance.literal) |
| Migration | 20/20 | [Results](migration-final-results.literal) | [Provenance](migration-final-provenance.literal) |
| Read projection | 3/3 | [Results](read-final-results.literal) | [Provenance](read-final-provenance.literal) |
| Publication | 4/4 | [Results](publication-mutation-results.literal) | [Provenance](publication-mutation-provenance.literal) |
| CLI boundaries | 10/10 | [Results](cli-mutation-results.literal) | [Provenance](cli-mutation-provenance.literal) |

A separate [advanced-draft sentinel](prefix-mutation-evidence.literal) killed
disabled prefix consumption, including its crash-ordering assertion, with restored
11/11 controls. The receipt-message key refactor has a separate
[current-source kill](receipt-message-mutation-results.literal) and
[provenance](receipt-message-mutation-provenance.literal): baseline 1/1,
mutant 0/1, restored 1/1. This revalidates the same core sentinel, not an extra
distinct mutant. All 70 current catalog targets match exactly once in the final
source. These are selected semantic mutations, not exhaustive fault coverage.

## Method and scope

[`mutation_check.tl`](mutation_check.tl) creates an isolated Git worktree at the
recorded revision. Provenance records the source tree SHA, catalog blob SHA,
exact substitutions, tests, optional exact test selectors, runtime, and explicit
source overlays. The core run used `dcf174707c01a9890a442cc0e775c7cea7a67b18`
and tree `0276e4e22335e934ebedc0a35acd33bec6b3c474`. The bounded run used
`2c6914bb4e2e57c9da8352296bb18baaef696017` and tree
`fed523749fa5a6e8dd00baed515dca0d53fea116`. Neither run used overlays.
The runner never mutates the shared checkout or accesses a live board or remote.
Source identity is retained through Git objects rather than a duplicate snapshot.

Each mutant must pass strict type checking. The real build pipeline generates
Lua, the enrolled test list, and its module manifest. The runner then executes
that Lua under a unique native test-output prefix. Only a fresh assertion failure
counts as a kill. Stale or ambiguous substitutions and compile/discovery failures
are invalid; other execution failures are errors. Cached verdicts do not count.
Checked-in results also name the failing test functions from the fresh logs.

Every selected test runs before mutation and after restoring the source. An
optional selector must identify exactly one enrolled function, and fresh execution
must report exactly one check; all three phases use the same selector. Without a
selector the full test file runs. Empty selection never establishes a result.

The core sentinels cover claim exclusion and identity, expiry, current authority,
first-parent receipt ancestry, claim read fences, publication deadline boundaries,
immutable transaction plans, complete receipt chains and message identity,
canonical remote reads, decimal sequence indices, and speculative research
results. Direct claims remain exclusion-only: one mutant incorrectly applies
the internal take readiness gate to ordinary claim acquisition.

Bounded sentinels cover retry exhaustion, dependency cycle/depth witnesses,
projected workload, rank target membership, both attach parent claims, old-parent
rank pruning, completion with a newly attached child, dependency endpoints, and
internal take workability. The bounded take/capacity validator is retained internal
compatibility machinery; these cases do not claim that public handover-oriented
`take` acquires a claim or enforces that policy.

## Iteration

Initial runs stopped on failing controls that exposed the incorrect application
of take policy to direct claims. Production and its direct-claim regression were
corrected before the final core run. An obsolete direct-claim capacity mutant was
removed and replaced with the mutant that wrongly applies take policy.

The frozen-transaction mutation was updated for the current decoded-copy source.
A dependency-cycle mutation retained the variable reference so strict compilation
could validate it. Neither stale substitutions nor compile failures count as kills.

The first bounded pass found that removing the old-parent rank replay guard
survived the existing command race: an earlier exact parent-path fence rejected
the stale command before replay. The added replay regression independently rejects
a moved child still ranked by its old parent, then accepts pruning that rank in
the same transaction. The stopped pass had three assertion kills and one survivor;
those outcomes are excluded from the final count.

## Reproduction

Run each current catalog from its repository checkout:

```sh
for catalog in mutations bounded-mutations migration-mutations \
  read-mutations publication-mutations cli-mutations; do
  bin/cosmic experiments/native/mutation_check.tl \
    "experiments/native/${catalog}.tl"
done
```

Each run writes `results.literal`, `provenance.literal`, compilation logs, and
baseline/mutant/restored execution logs under `o/native-state-mutations/<run>/`.
The final run directories were `SIJ6JyrQWR6PdweCrZufe8Sdk39AU0Wi` (core) and
`DjSEyVE018NEqXGULrvHHkM7ICbCQjl5` (bounded). The latter passed all 14 distinct
selected controls both before mutation and after restoration.
