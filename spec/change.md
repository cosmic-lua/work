`_work/action.tl` (and `flow.tl` where the stage derives): when the
accepted item's PR reports auto-merge enabled or `mergeable_state ==
"queued"` (the `gh.tl` PR read already carries the fields the verdict
verb reads), render the item as `queued` — listed under doing, never
offered by `next` as the head — and let `next` fall through to the
next actionable item. A `queued` item that leaves the queue without
merging returns to "awaiting merge". `done` is unchanged.

`_work/flow_test.tl` / `action_test.tl`: a fixture PR with
`auto_merge` set is not offered; one without it is.
