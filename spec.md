## Evidence

Parent item 3Isoczw9JmeVhX6X6NvBZCtZ5l7's rigor pass found `flow.tl` and
`priority.tl` are called from every one of the five mutation-verb files
(`gitgate`, `gitverdict`, `gitverbs`, `gitgraph`, `gitcompare`) for
write-time gates that need the exact, freshly-`store.list`-observed graph
— never a cache snapshot — and this dependency does not go away once
«VkzD_q8u2» lands: mutations will always need `store.list`'s freshness
for their own commit lease, and therefore will always need `{Item}`-taking
functions to reason about what they just loaded. `grep -rln 'require("_work.
flow")\|require("_work.priority")' _work cmd | grep -v _test` will still
name `gitgate`, `gitverdict`, `gitverbs`, `gitgraph`, `gitcompare` after
«VkzD_q8u2» and «6n1d_j0kB» both land — there is no point at which
"nothing requires either module" becomes true, which is what this item's
original `## Change` step 1 asked to confirm before deleting.

## Change

None — this item is withdrawn. `flow.tl` and `priority.tl` remain exactly
as they are, indefinitely: they are the mutation verbs' `{Item}`-taking
implementation, not a duplicate reader once every read verb hydrates its
`{Item}` list from the cache instead of git («VkzD_q8u2») — the
duplication the parent item exists to remove was between TWO READERS of
the same already-loaded state, not between the mutation verbs' needs and
anything else. Recommendation from the research: resolve not-planned; do
not relocate `DOING_LIMIT`/`STAGE_*`/`Position` anywhere.

## Non-goals

N/A — no change is being made.
