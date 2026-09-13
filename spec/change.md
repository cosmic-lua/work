`_work/brieftext_review.tl`'s "Recording your verdict" section (around
lines 78-82): branch the accept-landing instructions on the item's own
`base` field (already available where the template is filled) —
`base == "board"` (or more generally, the board repo's own base) emits
"merge directly via squash (`merge_method: squash` — this repository
rejects merge commits), then `gitboard done ID`"; any other base keeps
the existing "enable auto-merge, do NOT call done" text.

`_work/brief_test.tl` (or wherever review-brief fill tests live): a
fixture item with `base: board` renders the direct-squash-merge text;
one with `base: main` renders the existing auto-merge text.
