# Native format-6 validation

[Connector validation](VALIDATION.md) records the isolated GitHub validation
branch. [Mutation evidence](MUTATIONS.md) links the literal reports and provenance:
the initial 12/12 claim/transaction/read mutants and 3/3 bounded-policy mutants
killed, with passing baseline and restored controls. The expanded 15+7 catalogs
await their run on the published follow-up checkpoint. Migration's 12 mutants
are reported separately.

Run the semantic campaigns from the repository root:

```sh
bin/cosmic experiments/native/mutation_check.tl experiments/native/mutations.tl
bin/cosmic experiments/native/mutation_check.tl experiments/native/bounded-mutations.tl
```

The runner snapshots committed HEAD. Append `_work/FILE.tl` arguments to overlay
specific uncommitted sources; the exact overlay commands used for these reports
are in [MUTATIONS.md](MUTATIONS.md). All builds and mutations run in isolated
worktrees. Compile failures never count as kills.

The initial tip-only receipt mutant survived the older squash test. The new
receipt regression keeps the final transition exact while replacing an earlier
operation, independently requiring the complete first-parent chain; the final
campaign killed that mutant.
