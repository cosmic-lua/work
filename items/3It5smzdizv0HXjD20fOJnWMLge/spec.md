## Evidence

Parent item 3Isoczw9JmeVhX6X6NvBZCtZ5l7's rigor pass (`## Findings`, section
4) found `gitready.tl`, `intake.tl`, and `action.tl` each have ZERO
`store.list`/`store.load` calls of their own (`grep -c "store\.list\|store\.
load\b"` on each returns 0) — every `flow.*`/`prio.*` call in these three
files operates on an `items`/`all`/`pos` parameter the CALLER already
loaded. Tracing callers: `gitready.ready_problems` is reached from
`gitshow.tl:206` (a read, migrated by «VkzD_q8u2») and from `gitverbs.
tl:182` via `gitgate.review_debt_refusal` (a mutation, `take`'s own gate,
which loads its own `store.list` for the commit lease regardless).
`intake`/`action` are reached only from `gitview.tl`'s `status`/`next`
paths (migrated by «VkzD_q8u2»). Once that lands, all three of these files
already receive a cache-hydrated `{item.Item}` list from their callers, with
zero code changes of their own — hydration reproduces `store.list`'s
`{Item}` shape exactly (field-level proof in «VkzD_q8u2»'s Evidence), so
nothing downstream can tell the difference.

## Change

None. This item's entire premise — that `gitready`, `intake`, and `action`
need their own `require`/argument swap — does not hold once the actual call
graph is traced: they take `{Item}` from whichever caller loaded it, and
«VkzD_q8u2» is what changes what that caller loads. There is no file this
item can touch that «VkzD_q8u2» does not already cover. Recommendation from
the research: resolve not-planned citing this finding.

## Non-goals

Everything the parent's Non-goals already state; in particular, do not
duplicate `gitready.ready_problems`'s spec-bar logic into a second,
cache-specific implementation — it already runs correctly, unchanged,
against whatever `{Item}` list its caller supplies.
