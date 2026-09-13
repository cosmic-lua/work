`_work/gitgate.tl`'s `ci_clears_debt`: a diff clears the debt count
when the recorded observation is `running` or `red` **for the diff's
current head** — an observation recorded against a different head is
treated as absent. An absent observation for a head that was pushed
within the last 20 minutes (the PR's `head` recorded at `take --pr`
time, `touched_at` on the item) is treated as `running`, since a
push always starts CI and the cache simply has not caught up; older
than that, absent counts as debt as today. `_work/gittake_test.tl`:
a review-state item whose observation is `green` on the OLD head and
whose current head was recorded 5 minutes ago does not block a todo
take; the same with the head recorded an hour ago does.

`sync` (`_work/ciobs.tl` `at_sync`): also observe an item whose head
changed since its last observation, so the cache converges on the
first sync after a re-push.
