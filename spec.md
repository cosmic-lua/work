## Change

`refs.for_each_ref` (`_work/refs.tl`) asks git for
`%(committerdate:unix)` on every ref, which makes git read every tip
commit object: on the live clone's 1054 refs the snapshot costs 20 ms
with the date and 11 ms without (three runs each). Since the read
model, each item's `touched_at` lives in the cache row, written by
the save patch from the date the write stamped and by the fetch patch
from the snapshot it already took. Drop the date from the everyday
snapshot: `for-each-ref --format='%(refname) %(objectname)'` for the
digest, and read ages from `items.touched_at`; the fetch path, which
must learn dates for ids that moved under it, asks for the date of
those ids only (`refs.committer_date` exists). Keep `cache_test.tl`'s
ratchet holding: a rebuild still fills `touched_at` from a dated
snapshot. Measure the snapshot before and after and the bench's
`show`/`next`/`sync` medians in the PR.
