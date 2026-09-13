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
