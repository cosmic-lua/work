# Native format-6 validation

[Final integrated gate](FINAL_VALIDATION.md): **PASS**, 1,056/1,056 tests and
87.1% coverage, with clean strict types, formatting and lint.

[Connector validation](VALIDATION.md) records the isolated GitHub validation
branch. [Mutation evidence](MUTATIONS.md) links exact source provenance and
**70/70 kills** across six catalogs: core 18, bounded 15, migration 20, read 3,
publication 4, and CLI 10. Every baseline and restored control passed. A separate
advanced-draft sentinel covers prefix consumption and crash ordering.
The fresh [integrated source review](REVIEW.md) found no functional blockers.

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
