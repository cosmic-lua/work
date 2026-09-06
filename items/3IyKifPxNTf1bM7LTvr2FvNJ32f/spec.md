## Evidence

A `request-changes` verdict posts a formal `REQUEST_CHANGES` review
(work#62); an `accept` on the rework posts nothing that supersedes it,
so the PR stays `mergeable_state: blocked` under branch protection
until that review is dismissed: cosmic#1766 (2026-09-06 21:38) has the
round-2 accept recorded on the board and auto-merge armed, and cannot
merge — `GET /pulls/1766` → `"mergeable_state":"blocked"` with the
round-1 `changes_requested` review still standing. GitHub's dismissal
call is `PUT /repos/{owner}/{repo}/pulls/{n}/reviews/{id}/dismissals`
with a `message`; `git grep -n dismiss -- _work` → no hit.

## Change

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

## Non-goals

No approval review (GitHub refuses one on the token's own PR); no
change to request-changes.

## Access

cosmic-lua/cosmic and cosmic-lua/work, read (the reviews list) and
write (the dismissal), through `_work.api`.

## Constraint measured 2026-09-06

The same PUT from this remote session's proxy →
`HTTP 403 {"message":"Dismissing pull request reviews is not permitted
for this session type."}` — a policy of the session's GitHub proxy,
not of the token. So this dismissal works from a local session only;
the durable fix is «Qa2H_5whT» (a `COMMENT` review never blocks a
merge), which should land first and makes this item the fallback for
reviews posted before it.
