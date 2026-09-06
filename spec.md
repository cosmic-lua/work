## Evidence

Every second-round review this pass got a hand-written "Round 2
context" block from the orchestrator — the round-1 findings verbatim,
the rework commit, the exact mutation to repeat, and "do not
relitigate" for what round 1 settled — and it cut the round: PR 1759
40 → 25 calls, work#61 52 → 31, PR 1764 19 → 11, PR 1765 32 → 26
(`cosmic _tool/friction.tl` over each transcript). `brief review`
emits the same round-1 text for a rework item: `git grep -n 'round'
-- _work/brieftext_review.tl _work/brief.tl` → no round-aware
sentence; the item's own `verdict` field carries "request changes
(head <sha>)" and, since work#62, the formal REQUEST_CHANGES review
body the reviewer posted is fetchable by head.

## Change

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

## Non-goals

No change to the builder brief's bounce context; no change to the
verdict verb.

## Access

cosmic-lua/work and cosmic-lua/cosmic, read only: the review body by
head, through the existing `_work.gh` client.
