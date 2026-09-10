## Evidence

Direct before/after/original-baseline measurement of `_make/deps.tl`'s
`closure()`, called once per file across the whole `cosmic-lua/cosmic`
tree (the exact scenario `#1828`'s review and `#1829`'s fix both
measured), using a small standalone benchmark
(`project.scan` + `deps.index` once, then `deps.closure(proj, f,
by_import)` per file, timed with `os.clock()`):

| build | files | elapsed (3 runs) | per-file |
|---|---|---|---|
| pre-`#1828` (`a44b020d`, the original 3x-duplicated BFS `closure`) | 944 | 0.4665s / 0.4652s / 0.4792s (avg 0.470s) | ~0.498ms |
| post-`#1829` (`f8149470`, `cosmic.graph` + the memoization fix) | 949 | 0.5073s / 0.5502s / 0.5098s (avg 0.522s) | ~0.551ms |

`#1829` closed the 230x regression `#1828` introduced (confirmed
separately: the pre-`#1829`, post-`#1828` state measured 3.216s for the
same 949-file run — over 6x slower than either baseline above). But
`#1829`'s fix only memoized graph *construction*; it did not touch
`closure()`'s own per-call work of converting `graph.reach()`'s reached
node-id set back into a `{File}` list (table build, id-to-`File`
lookups). The isolated `graph.reach()` primitive alone, after a single
graph build, costs 0.009s total across all 949 files — three orders of
magnitude below either row above. The ~10% gap between the two rows
above is entirely inside `closure()`'s own wrapper, present in both
implementations in different shapes, and was called out as
out-of-scope by `#1829`'s own author ("this residual 0.559s ... is
`closure()`'s own pre-existing O(n) per-call conversion ... unrelated
to this fix").

## Non-goals

Not urgent: ~0.05ms/file, well under the noise floor most build-time
budgets care about, and current performance is close to (not
dramatically worse than) the pre-`#1828` baseline — this is a residual
tuning gap, not a regression needing a hotfix. Filing so the number is
on record rather than lost, for whoever next touches `_make/deps.tl`
or wants `cosmic.graph.reach()`'s speed to actually reach every
caller.
