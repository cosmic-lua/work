## Evidence

2026-09-06 (work4), in order, same session, same minute:

    gitboard-take: REFUSED: 1 diff(s) await a verdict you can give and
    outrank this take — verdicts before new work: `take 3ItPDYTw`
    claims the first; a recorded reviewer clears it
    gitboard-brief: REFUSED: 3ItPDYTw's head 8811dc3 has CI running
    (2 of 6 checks done) — review when it settles

A todo pull is refused because an unclaimed diff awaits a verdict; the
review of that diff is refused because its CI is running. Until CI
settles (cosmic's lanes take 8–15 minutes) the session can neither
build nor review — the queue's "reviews outrank pulls" rule
(`gitboard help system`) is enforced against a review the same tool
will not let anyone start. The refusal's own remedy (`take 3ItPDYTw`)
is the command that is refused. `_work/gittake.tl` holds the pull
gate; the CI-settled check is the one `brief review`/`take` share
(`_work/review.tl`, the "has CI running" refusal).

## Change

The pull gate counts only diffs a review could be CLAIMED for right
now: a diff whose head has CI running (or concluded failure — that one
goes back to its builder, not a reviewer) does not outrank a todo
pull. Concretely, `_work/gittake.tl`'s "diff(s) await a verdict you
can give" predicate applies the same head-state check the review
claim applies, and a diff with CI in progress or failed is excluded
from the count. The refusal text, when it still fires, is unchanged.
`_work/gittake_test.tl`: a doing item with a PR whose recorded head
state is `running` does not block a todo take; one whose state is
`success` still does.

## Non-goals

No change to the review claim's CI-settled refusal, which is right.
