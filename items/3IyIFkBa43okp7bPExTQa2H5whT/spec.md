## Evidence

`gitboard verdict request-changes --body FILE` posts a formal
`REQUEST_CHANGES` review (work#62). `take --open` (work#61) opens the
PR with the same token, so GitHub sees the reviewer requesting changes
on its own pull request and refuses: on cosmic#1768 (opened by
`--open`, 2026-09-06 21:31) the reviewer's verdict twice returned
`gitboard-verdict: REFUSED: POST /repos/cosmic-lua/cosmic/pulls/1768/reviews:
HTTP 422: Unprocessable Entity` and nothing was recorded — the
reviewer's finding (a real defect) reached the board only through its
chat report. On cosmic#1766, opened by a builder through the GitHub
connector under a different identity, the same command succeeded.
GitHub allows a `COMMENT` review on one's own PR; `APPROVE` and
`REQUEST_CHANGES` are what it refuses. Every PR `--open` opens is the
token's own, so every bounce of such a PR fails today.

## Change

`_work/ghwrite.tl` `post_review`: when the PR's `user.login` (already
in the `pull` payload) equals the token's own login (`GET /user`, one
call, cached per process in `_work/api.tl`), post the review with
`event = "COMMENT"` and the body prefixed by its kind on the first
line (`request-changes:` / `reject:`); otherwise `REQUEST_CHANGES` as
today. `_work/brief.tl`'s bounce context reads the latest review by
head regardless of `state`, keyed on that first-line prefix, so a
rework brief still fills. `_work/ghwrite_test.tl`: a PR authored by
the token's login → `COMMENT` with the prefix; another author →
`REQUEST_CHANGES`. `_work/brief_rework_test.tl`: a `COMMENT` review
with the prefix fills the bounce context.

## Non-goals

No second identity; no change to `accept`'s merge path (merging one's
own PR is allowed).

## Access

cosmic-lua/work and cosmic-lua/cosmic, read (`GET /user`, the PR
payload) and write (the review), through the existing `_work.api`
client.
