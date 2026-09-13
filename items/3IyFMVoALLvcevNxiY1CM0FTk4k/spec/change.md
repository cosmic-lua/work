`_work/brief.tl`: when the item's last recorded verdict is
`request-changes` and the PR's head has moved past the judged one,
`brief review` fills a new `<ROUND_CONTEXT>` placeholder in
`_work/brieftext_review.tl`'s `REVIEW` template (a section between
"The spec" and "How to review"): the judged head, the current head,
the verdict's round number, and the round-1 review body (the formal
review `verdict` posted, read through `_work.gh` by head), followed by
the fixed sentence "Confirm each finding above is closed — repeat its
own reproduction — then judge the whole diff; what round 1 accepted
is settled." On a first round the placeholder fills as empty.
`_work/brief_rework_test.tl`: a fixture item with a recorded
request-changes verdict and a fake-transport review body → the brief
contains the body and the sentence; a first-round item → neither.
