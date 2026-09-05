## Evidence

«Z6Lr_dQVQ» ports `_work/api.tl` — the authenticated, ETag-cached,
rate-aware transport — as `cosmic.github`. What sits on top of it in
cosmic-lua/work is a second generic layer that item does not name:
`_work/gh.tl` (323 lines, 2026-09-05) reads one pull request (`pull`,
line 67: state, head sha, merged, draft, base ref), its check runs
(`checks`, 126, paginated `/commits/<sha>/check-runs` reduced to
name/status/conclusion), the head's combined state (`head_state`, 188),
its reviews (`reviews`, 224) and the latest changes-requested review
(`latest_request_changes`, 263); `_work/lanes.tl` `observe_one` (line 125)
reads a workflow's last completed run conclusion from
`/actions/workflows/<file>/runs?per_page=1&status=completed`.

Every one of these is "call the endpoint, check `is_success`, walk the
JSON with `is {string: any}` guards, return a typed record" — nothing
board-shaped. The board-shaped half is separate by design: `_work/review.tl`
(pure, "what the fetched values MEAN") consumes the records. The only
coupling to the store is `slug`'s memoized `git remote get-url origin`
read, which belongs to the git side («teX8_bEiz»'s addendum names it).

## Change

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

## Non-goals

Any write to GitHub (that decision is «Z6Lr_dQVQ»'s step 2); porting
`_work/review.tl`, `_work/ciobs.tl` or `_work/lanes.tl`'s board meaning
(freshness windows, repair items, what "green" earns) — those stay in
gitboard; the work-side port (a follow-up).
