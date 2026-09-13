- No code in this item; the build is «bj12_PZHY», whose spec is
  rewritten to match this decision as a follow-up edit.
- Not re-litigating the `for … in` body fix's correctness itself —
  the reviewer confirmed that half of the original PR worked; only
  the terminating-call honesty gap was ever in question.
- Not mandating a specific accessor name/method shape for `FileIter`
  or the promoted `LineIter` record — that is `bj12_PZHY`'s own
  build-time refinement, consistent with this repo's existing naming
  conventions (charter, D20).
