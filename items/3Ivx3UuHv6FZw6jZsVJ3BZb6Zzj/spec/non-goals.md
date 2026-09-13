Not a claim that this makes the `bj12_PZHY`/PR #1740 fix incomplete —
every real call site in that PR's diff uses indexing or a method call,
which the checker already catches; this is a general checker gap this
review's probe happened to expose, unrelated to that PR's own
correctness.
