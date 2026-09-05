## Evidence

Parent item 3Isoczw9JmeVhX6X6NvBZCtZ5l7's rigor pass found every
`flow.*`/`prio.*` call in `gitgate.tl` (0 direct `store.list` calls — it is
a pure function library for write-time gates, e.g. `review_debt_refusal`,
called only from `gitverbs.tl:182` inside `cmd_take`, a mutation),
`gitverdict.tl` (2 `store.list` calls, both inside the mutation `verdict`),
and `gitverbs.tl` (6 `store.list`/`store.load` calls, all inside the
mutation verbs `take`/`drop`/`done`/`sync`) sits inside a mutation that
already loads a fresh `store.list` for its own commit lease
(`gate.commit_and_publish`'s optimistic-concurrency check needs the exact
git-observed state, not a cache snapshot). None of these three files has a
duplicate read to eliminate: the `store.list` they pay for is the ONE read
their own write already requires, not a second one alongside a cache open.

## Change

None. Migrating these calls to a cache handle would add a read (opening the
cache) without removing one (the mutation's own `store.list` stays,
required), making these verbs slower, not faster — the opposite of this
parent item's purpose. Recommendation from the research: resolve
not-planned citing this finding.

## Non-goals

Everything the parent's Non-goals already state.
