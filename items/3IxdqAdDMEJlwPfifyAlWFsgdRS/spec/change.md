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
