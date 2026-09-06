## Evidence

`gitboard help review`: "`accept` — merge (a PR against the product repo
lands by enabling auto-merge …), then `done ID`"; "`request changes` —
the concrete gaps quoted on the PR". Both are GitHub WRITES the review
agent performs itself with the `gh` CLI or MCP tools before it records
the verdict, so every reviewer needs a GitHub write path, and the verdict
gitboard records is not the action that landed the PR — the two can
disagree (a verdict recorded, the auto-merge never enabled, or the
reverse). The board already reads everything a verdict needs:
`_work/gitverdict.tl:182` fetches the PR (`gh.pull`), `:231` reads
`merged`/`merge_sha`, and `brief review`/`take` already refuse while CI
runs ("head 071cb8a has CI running (0 of 2 checks done) — review when
it settles", observed 2026-09-06), so at verdict time the head's checks
are settled by construction.

Line counts (`wc -l`, main, 2026-09-06): `_work/gitverdict.tl` 319,
`_work/gitverdict_test.tl` 393, `_work/gh.tl` 323,
`_work/brieftext_review.tl` 208, `_work/gitcommands.tl` 187.

Ready when: `grep -n 'body: string' _work/api.tl` prints the write-path
signature from the sibling item «gitboard take --open» (its PR merged);
until then this item is not buildable — drop bare.

## Change

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

## Non-goals

No change to the verdict kinds, the distance guard, or the head/spec
recording. No merge of a PR whose judged head is not the current head
(the `sha` field guarantees it). No retry loop: a failed landing is one
verdict line the orchestrator acts on.
