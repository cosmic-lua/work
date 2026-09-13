`_work/brieftext_review.tl` (or wherever the review template's "Recording
your verdict" accept instructions render): branch the accept landing
instructions on the item's recorded base/target branch — `board` merges
directly (squash), any other branch (e.g. `main`) uses
`enable_pr_auto_merge` (squash), never a direct merge. State both branches
explicitly rather than leaving the board case to `gitboard help review`
alone.

Alternatively (equal or higher leverage, orchestrator's call): have
`gitboard verdict`'s `accept` output itself print the correct landing
instruction for the item's recorded base, so the fix lives in one place
regardless of which brief template renders it.

`_work/brieftext_review_test.tl` (or the appropriate pin-test file): pin
that a `board`-based item's rendered review brief says "merge directly"
and a non-`board` item's says "enable auto-merge."
