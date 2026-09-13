`_work/ghwrite.tl`: `dismiss_review(s, repo, number, review_id,
message): boolean, string` — the PUT above. `_work/gitverdict.tl`'s
accept path: before landing, list the PR's reviews (`GET
/pulls/{n}/reviews`), and dismiss every `CHANGES_REQUESTED` review
whose author login is the token's own (the round-1 verdict this
accept supersedes) with the message `superseded by the accept on
<head7>`; a review by anyone else is left standing and the verdict
line says so. `_work/gitverdict_land_test.tl`: a fake transport with
one own `CHANGES_REQUESTED` review → the dismissal PUT is sent before
the merge PUT; a foreign review → no dismissal, the line names it.
