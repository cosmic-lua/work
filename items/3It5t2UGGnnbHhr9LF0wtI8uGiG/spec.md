## Evidence

Parent item 3Isoczw9JmeVhX6X6NvBZCtZ5l7's coverage table classifies every
function these three modules call: `gitgate` uses `flow.STAGE_REVIEW/
is_doing/role/stage_rank/unified` and `prio.positions`; `gitverdict` uses
only `flow.by_id`; `gitverbs` uses `flow.binds/by_id/doing_refusal/
is_blocked/is_doing/role/substate`. All are `same` except `by_id`
(superseded). `gitgate`'s `stage_rank`/`unified` calls need the lift/
tie-break helper item (a) builds; `gitverdict` needs no migration at all
beyond dropping its now-superseded `by_id` call.

## Change

`_work/cacheread.tl` (built by follow-up (a), which this item is
`blocked_by`) already exposes every function these three files need.
Migrate `gitgate`, `gitverdict`, and `gitverbs`: swap
`require("_work.flow")` for `require("_work.cacheread")` and each call
site's `{Item}` argument for the cache handle; `gitverdict`'s single
`by_id` call site is simply deleted, using a direct row lookup instead.

## Non-goals

Changing any view's definition or the STRICT schema; changing `gitgate`'s,
`gitverdict`'s, or `gitverbs`'s printed output — `gitgate` is the
mutation gate every verb commits through, so its refusal strings and
ordering are especially load-bearing; touching any file outside these
three plus `_work/cacheread.tl`'s call sites; deleting `flow.tl`/
`priority.tl`.
