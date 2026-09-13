`gitboard verdict` performs the GitHub side of the verdict it records,
so a reviewer runs exactly one command and touches no GitHub tool.

- `accept`: after the existing checks pass and before the verdict
  commit, land the PR: `PUT /repos/<slug>/pulls/<n>/merge` with
  `{merge_method = "squash", sha = <judged head>}` (the `sha` field
  makes a head that moved since the review a refused merge, not a
  merge of unreviewed code). On 405/409 (branch protection, a merge
  queue, or "not mergeable") fall back to enabling auto-merge through
  the GraphQL `enablePullRequestAutoMerge` mutation (`POST /graphql`,
  `mergeMethod: SQUASH`, the PR's node id from the `pull` payload's
  `node_id`) and record the verdict with the existing "awaiting merge —
  land it" outcome; on a successful merge, record it and end the item
  in the same run as today's already-merged path (`gitverdict.tl:231`).
  `--no-land` skips the GitHub write and records only, for a repo the
  token cannot merge.
- `request-changes --body FILE`: `POST /repos/<slug>/pulls/<n>/reviews`
  with `{event = "REQUEST_CHANGES", commit_id = <judged head>, body =
  FILE's text}` — a formal changes-requested review, which is what
  «IB9Z_CwM4» found `bounce_context()` looks for and a plain comment
  never satisfies. `--body` is required for this kind: refuse on the
  verdict line without it. This supersedes «IB9Z_CwM4»'s text-only
  change: end that item `not-planned` citing this one when this merges.
- `reject`: `PATCH /repos/<slug>/pulls/<n>` with `{state = "closed"}`
  after posting the same review with `--body FILE` (required), then
  the existing clear-the-claim path.
- `_work/gh.tl`: `merge_pull`, `enable_auto_merge`, `post_review`,
  `close_pull` — thin wrappers, each `boolean, string`, each tested for
  request shape through the transport seam the sibling item added.
- `_work/gitcommands.tl`: `--body FILE` and `--no-land` on `verdict`.
- `_work/brieftext_review.tl`, "Recording your verdict": the three
  bullets become three `gitboard verdict` command lines and nothing
  else — no `gh`, no MCP tool, no "enable auto-merge" instruction; CI
  is read from `gitboard show ID` (the board's own head-check
  observation), and the diff from `git fetch origin <branch>` in the
  reviewer's own checkout. Update `_work/brieftext_test.tl`'s case from
  #44 accordingly (no `enable_pr_auto_merge` mention).
- `_work/gitverdict.tl` is at 319 and gains the landing branch; keep it
  under 500 by putting the GitHub calls in `gh.tl` and only the
  decision (merge → auto-merge → record) here.
