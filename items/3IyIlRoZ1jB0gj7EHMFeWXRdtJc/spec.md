## Evidence

`gitboard verdict accept` (work#62) lands the PR — a merge PUT, then
on 405/409 the GraphQL `enablePullRequestAutoMerge` mutation — BEFORE
recording the verdict, and a failed landing refuses the whole verb:
work#64's reviewer (2026-09-06 21:36) got
`gitboard-verdict: REFUSED: POST /graphql: HTTP 403: This GraphQL query
is not enabled for this session — only the pinned set of PR-review
operations is served` twice, and nothing was recorded; the judgment
reached the board only through the reviewer's chat report and the
orchestrator re-ran the verb with `--no-land`. The merge PUT is refused
by the merge queue on both repos, so in any environment whose proxy
pins the GraphQL operations, every accept fails this way. A verdict is
the review's deliverable; the landing is a courtesy.

## Change

`_work/gitverdict.tl`: record first, land second. An `accept` writes
the verdict commit exactly as `--no-land` does, then attempts the
landing; a landing failure is reported on the verdict line after the
recorded outcome — `gitboard-verdict: accept on <id8>: awaiting merge
— landing failed (<status> <path>: <message>), land it by hand` — and
the verb exits 0 (the verdict stands). `_work/gitverdict_land_test.tl`:
a fake transport whose GraphQL call returns 403 → the verdict is
recorded and the line names the failure; the merge-succeeds and
auto-merge-succeeds cases unchanged.

## Non-goals

No retry; no REST substitute for auto-merge (GitHub has none).
