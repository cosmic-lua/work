`_work/brieftext_review.tl`'s "Recording your verdict" section,
`request-changes` bullet: change the instruction from posting a plain
PR comment to posting a formal GitHub PR review in the
`CHANGES_REQUESTED` state, using the GitHub MCP server's own documented
workflow (its tool instructions: "Always use `pull_request_review_write`
with method 'create' to create a pending review, then
`add_comment_to_pending_review`... and finally `pull_request_review_write`
with method 'submit_pending'") — for a single overall-findings body (no
per-line comments needed here), `pull_request_review_write` with
method `create` and an `event`/`state` of `REQUEST_CHANGES` and the
findings as the review `body` in one call should suffice; verify the
exact parameter shape against the tool's current schema when
implementing, since this file describes the write pattern, not the
exact call signature.

Keep the existing guidance to quote gaps with file:line and to not
push a fix — only the delivery mechanism (formal review vs. plain
comment) changes.

`_work/brief_test.tl` or `_work/brief_rework_test.tl` (check current
headroom — see the sibling item on `product_root()` for both files'
line counts as of 2026-09-06, prefer whichever has room): add a test
that a rendered review brief's request-changes instructions name
`pull_request_review_write` (or the review-object-creating call) and
do not say "PR comment" for this bullet.
