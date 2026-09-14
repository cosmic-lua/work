# Native format-6 validation

[Connector validation](VALIDATION.md) records the isolated GitHub validation
branch. [Mutation evidence](MUTATIONS.md) links the literal reports and provenance:
the initial 12/12 claim/transaction/read mutants and 3/3 bounded-policy mutants
killed, with passing baseline and restored controls. Those are historical runs.
The current consolidated suite has six catalogs: main, bounded, migration,
read, publication, and CLI. Its final integrated totals are pending and must be
recorded from that exact checkout.

Run the semantic campaigns from the repository root:

```sh
bin/cosmic experiments/native/mutation_check.tl experiments/native/mutations.tl
bin/cosmic experiments/native/mutation_check.tl experiments/native/bounded-mutations.tl
bin/cosmic experiments/native/mutation_check.tl experiments/native/migration-mutations.tl
bin/cosmic experiments/native/mutation_check.tl experiments/native/read-mutations.tl
bin/cosmic experiments/native/mutation_check.tl experiments/native/publication-mutations.tl
bin/cosmic experiments/native/mutation_check.tl experiments/native/cli-mutations.tl
```

The runner snapshots committed HEAD. Append `_work/FILE.tl` arguments to overlay
specific uncommitted sources; the exact overlay commands used for these reports
are in [MUTATIONS.md](MUTATIONS.md). All builds and mutations run in isolated
worktrees. Compile failures never count as kills.

The initial tip-only receipt mutant survived the older squash test. The new
receipt regression keeps the final transition exact while replacing an earlier
operation, independently requiring the complete first-parent chain; the final
campaign killed that mutant.
