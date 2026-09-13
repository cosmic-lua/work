Blocked on «Z6Lr_dQVQ» landing (the transport and its `call`).

1. `cosmic/github/pulls.tl` (or wherever «Z6Lr_dQVQ» settles the
   directory): `pull(slug, number) -> Pull | nil, string`, `reviews(slug,
   number) -> {Review} | nil, string`, `latest_request_changes(reviews)`
   (pure), with `Pull`/`Review` records ported from `_work/review.tl`'s
   field subsets.
2. `cosmic/github/checks.tl`: `check_runs(slug, sha) -> {CheckRun} | nil,
   string` (paginated, all pages), `combined_status(slug, sha)`.
3. `cosmic/github/actions.tl`: `last_run(slug, workflow_file, opts)` for
   the lane read, returning the run's conclusion, id, head sha and
   timestamps.
4. Each reader takes an explicit `slug` (`owner/repo`); deriving it from a
   checkout's origin is `cosmic.git`'s (the addendum to «teX8_bEiz»), so
   this module never shells out.
5. Tests: the JSON-walking is exercised with canned response bodies (no
   network), one fixture per endpoint copied from a real response with
   fields trimmed; `latest_request_changes` ported from
   `_work/gh_test.tl`.
