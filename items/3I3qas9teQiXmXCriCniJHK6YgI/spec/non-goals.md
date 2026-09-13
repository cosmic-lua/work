- no new resolution kind: "landed" stays `completed`-from-`land` in the
  trail, not a schema change.
- no change to `gh.refusal`'s 403/ERROR texts, to `review.blocks_check`
  (a merged PR is `closed` and still refuses `check` entry — correct),
  or to the merge method.
- no retry loops, no 405 sub-classification.
- `cmd_land`'s merge-then-done ordering for the unmerged path is settled
  by the module's own header comment; do not reorder it.
