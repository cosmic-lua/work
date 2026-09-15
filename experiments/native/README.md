# Native format-6 validation records

The Markdown and literal result files preserve historical validation at the
source revisions they name. Counts and connector exercises in those records do
not describe the current tree. In particular, the saved transition planner,
draft workflow, indexed connector CLI, and JavaScript Work adapter are retired.

[Snapshot publication evidence](SNAPSHOT_PUBLICATION_EVIDENCE.md) preserves the
later implementation record and identifies the retired adapter explicitly.

Run the semantic campaigns from the repository root:

```sh
bin/cosmic experiments/native/mutation_check.tl experiments/native/mutations.tl
bin/cosmic experiments/native/mutation_check.tl experiments/native/bounded-mutations.tl
bin/cosmic experiments/native/mutation_check.tl experiments/native/migration-mutations.tl
bin/cosmic experiments/native/mutation_check.tl experiments/native/read-mutations.tl
```

The runner snapshots committed HEAD. Append `_work/FILE.tl` arguments to overlay
specific uncommitted sources; the exact overlay commands used for these reports
are in [MUTATIONS.md](MUTATIONS.md). All builds and mutations run in isolated
worktrees. Compile failures never count as kills.

Historical catalogs removed from this list must be reproduced from their named
source revisions rather than run against current code.
