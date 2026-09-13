Speed up `_make.deps.closure` by projecting sparse reached-node sets through
a cached path-to-project-position index instead of scanning every project
file on every call. Preserve the existing scan for dense closures. Keep
`cosmic.graph.reach` as the graph algorithm and retain the existing
single-snapshot cache lifetime. No persistent cache, public API, C change,
runtime pin change, or graph-algorithm rewrite.

This is design only. Four dependency-ordered children cover contract tests,
an executable benchmark, the optimization, and independent verification.
The original unranked capture is attached last under G6, without moving any
existing work ahead of another item.

Implementation sequence (each earlier row is a prerequisite child of
the following row):

1. [Exact contract tests](https://github.com/cosmic-lua/work/blob/items/3JDEbBj5PhIk52zynuPOzrSRJBu/spec.md)
2. [Checked benchmarks](https://github.com/cosmic-lua/work/blob/items/3JDEb7AbODYUb9xm5gwRojFmibe/spec.md)
3. [Sparse projection](https://github.com/cosmic-lua/work/blob/items/3JDEb1FFGt6Kw92rokUyHQYgJGD/spec.md)
4. [Independent verification](https://github.com/cosmic-lua/work/blob/items/3JDEav2cqkdwFEIHSsKcPq9FvtC/spec.md)
