1. `_work/events_test.tl`: one fixture item taken on PR 5, then PR 6, then
   PR 5 again, accepted on the last; assert `pr_rounds` yields three rows
   in `seq` order, with `accepted_at` set only on the third, and that the
   rework query counts the item once.
2. Confirm the mutation above fails this case before landing; say so in
   the PR.
