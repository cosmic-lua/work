# brief review: the shared request-changes tail still speaks diff to a research reviewer

## Change

After #158, #160 and #162 the research review renders its own opening, its
own posture and its own final report, and the diff form is byte-identical to
before. One diff-shaped sentence survives in the SHARED tail of `REVIEW`
(`_work/brieftext_review.tl`, after `{{.posture}}`): "the focused regression
plus every named boundary guard the corrected head must rerun". "Regression"
and "boundary guard" are diff words; a research rework's "corrected head" is a
new board commit and what it must rerun is each measured claim. The #162
review flagged it as outside that item's three named sentences.

Splice it the way #162 spliced the opening: a `TAIL_DIFF`/`TAIL_RESEARCH`
pair over one shared record, chosen by `findings ~= nil`, the diff text
byte-for-byte the current sentence so the diff render digest
(`b3b6993ae9ce04ab0abaf4c8f54f4ff8ab7dea21697ef6e71e714e7ab7447fb3` against
`brieftmpl_test`'s fixture facts) does not move. Pin the research wording in
`brief_research_test` and `brieftmpl_test`.

## Non-goals

- No other sentence moves; the diff render stays byte-identical.
- `POSTURE_RESEARCH`'s hard line break mid-paragraph ("...reproduction
  worktree above.\nThe checkout that holds...") is cosmetic and may ride
  along, but is not the item.
