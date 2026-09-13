`_work/review.tl`, `blocks_land`'s message: name the verb that exists —
"PR #N is not merged — `done` ends an item whose merge is done, it does
not merge. Once PR #N is squash-merged (auto-merge or the queue), re-run
`gitboard done <id8>`, which reads the merge and ends the item." Keep
the head-moved suffix unchanged. `_work/review_test.tl`: the existing
case for this refusal asserts the text contains "gitboard done" and
not "gitboard land".
