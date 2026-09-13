`take --result` itself, which is unchanged: it records the handover and
this item makes that handover reviewable.

The `state` and `substate` views, and the review-claim routing. Both
already read `result` correctly; the brief path was the only one
refusing it.

`verdict`. Its doc comments claim it refuses a spec that moved since the
handover, which is false today — `grep -n 'verdict_spec\|revision' 
_work/gitverdict.tl` prints one line and it is `it.verdict_spec = ""`.
Correcting those comments is its own change and belongs with whatever
decides whether that refusal should exist.

The 19 items carrying a legacy digest in `result`. The migration carries
them through verbatim; a digest is not a commit, so a review brief for
one still refuses, and re-typing happens on its next handover.
