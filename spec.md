## Evidence

The second review of cosmic-lua/work#38 («KYPX_s06P», 2026-09-05)
hand-traced `pr_rounds`'s gaps-and-islands grouping
(`_work/cachedb_events.tl:66-96`) for an item taken on PR 5, then PR 6,
then PR 5 again: the view correctly reports three rounds with the accept
attributed to the reused PR 5 round. But the mutation `PARTITION BY item,
pr` → `PARTITION BY item` on the second `ROW_NUMBER` passes every shipped
test (`_work/events_test.tl`'s fixtures never reuse a PR non-adjacently),
while a standalone harness showed the mutant merges the two PR 5 runs and
misattributes the accept. The live board has no such item today (a scan
found 0), so nothing exercises the path.

## Change

1. `_work/events_test.tl`: one fixture item taken on PR 5, then PR 6, then
   PR 5 again, accepted on the last; assert `pr_rounds` yields three rows
   in `seq` order, with `accepted_at` set only on the third, and that the
   rework query counts the item once.
2. Confirm the mutation above fails this case before landing; say so in
   the PR.

## Non-goals

Changing the view; any other query.
