## Evidence

`gitboard done ID` on an accepted item whose PR is still in the merge
queue refuses with (`_work/review.tl:192-194`):

    gitboard-done: REFUSED: PR #44 is not merged — `land` ends an item whose
    merge is done, it does not merge. Squash-merge PR #44, then re-run
    `gitboard land 3Ixa3D2Q`, which reads the merge and ends the item.

but `gitboard land` is not a verb: `bin/gitboard land --help` →
`unknown command 'land': init, new, attach, rank, set, spec, next,
brief, take, drop, verdict, done, show, sync, fsck, find`. The verb
that reads the merge and ends the item is `done` itself (the refusal
came from it). Observed 2026-09-06 work4: one wasted call following
the refusal's own instruction. `grep -rn 'gitboard land' _work/*.tl`
→ only `_work/review.tl:194`; `wc -l _work/review.tl` → 258,
`_work/review_test.tl` → 241.

## Change

`_work/review.tl`, `blocks_land`'s message: name the verb that exists —
"PR #N is not merged — `done` ends an item whose merge is done, it does
not merge. Once PR #N is squash-merged (auto-merge or the queue), re-run
`gitboard done <id8>`, which reads the merge and ends the item." Keep
the head-moved suffix unchanged. `_work/review_test.tl`: the existing
case for this refusal asserts the text contains "gitboard done" and
not "gitboard land".

## Non-goals

No new verb. No change to what `done` checks.
