## Evidence

`_work/ghwrite.tl`'s `enable_auto_merge` calls GitHub's `enablePullRequestAutoMerge`
GraphQL mutation. Board item `3nAe_st3T` (completed) found this mutation gets
a 403 specific to a sandboxed/remote calling environment, distinct from the
repo-level auto-merge setting (`c77H_v0vS`, confirmed enabled and working):
`"This GraphQL query is not enabled for this session — only the pinned set
of PR-review operations is served. Use REST via 'gh api repos/{owner}/{repo}/...'
instead."` A DIFFERENT tool using the orchestrating session's own broader
credentials succeeded immediately every time; gitboard's own attempt did not.

Reproduced and diagnosed further under `f6jE_UJBu`, 2026-09-12, in a live
Claude Code Remote session: a direct GraphQL call (even a trivial read,
`query { viewer { login } }`) returns HTTP 403 from an Anthropic-operated
proxy: `"GitHub GraphQL is not available from Claude Code sessions; use the
REST API... For review threads, auto-merge, and draft/ready-for-review use
the CCR routes on api.github.com: ... PUT or DELETE
/repos/{owner}/{repo}/pulls/{n}/ccr/auto_merge ..."`. Verified live and
working end-to-end on a disposable PR (`cosmic-lua/work#138`, opened,
probed, and closed without merging):

- `POST /repos/{owner}/{repo}/pulls/{n}/ccr/ready_for_review` → `200
  {"draft":false}`
- `PUT /repos/{owner}/{repo}/pulls/{n}/ccr/auto_merge` with
  `{"merge_method":"squash"}` → `200 {"enabled":true,"merge_method":"squash"}`
- `DELETE /repos/{owner}/{repo}/pulls/{n}/ccr/auto_merge` → `200
  {"enabled":false}`
- `GET /repos/{owner}/{repo}/pulls/{n}/ccr/review_threads` → `200 []`

Plain REST calls (`merge_pull`'s `PUT .../pulls/{n}/merge`, and by inference
`post_review`'s `POST .../pulls/{n}/reviews` and `close_pull`'s `PATCH
.../pulls/{n}`) are NOT GraphQL and are not subject to this specific block —
`merge_pull`'s live test on the same disposable PR got an ordinary GitHub
405 ("Changes must be made through the merge queue"), exactly the shape
`ghwrite.tl`'s own doc comment already anticipates as the auto-merge
fallback's trigger, not a Claude-specific refusal.

## Change

`_work/ghwrite.tl`'s `enable_auto_merge`: attempt the GraphQL mutation
first, unchanged — this keeps the function correct in any environment where
GraphQL is available (a plain CI runner with an unrestricted PAT, for
instance). On a 403 whose body matches this specific proxy's refusal shape
(match on the distinguishing substring, e.g. `"GraphQL is not available
from Claude Code sessions"` — do not match on a generic 403, which has many
unrelated causes), retry via `PUT /repos/{owner}/{repo}/pulls/{n}/ccr/auto_merge`
with the same `merge_method`, parsing its `{"enabled": bool}` shape instead
of GraphQL's `errors` array. Preserve the existing `boolean, string` return
shape and error rendering for both paths.

Add fixture cases to `_work/ghwrite_test.tl` (which already fakes
`api.call`/the transport) for: the GraphQL path succeeding as today, the
GraphQL path refused with the CCR-shaped 403 and the REST fallback
succeeding, and the GraphQL path refused with an UNRELATED 403 (should NOT
attempt the CCR fallback — surface the original error instead, since that
403 is a different, real refusal a caller needs to see honestly).

## Non-goals

Not adding CCR routes for `ready_for_review`/`convert_to_draft` — gitboard's
own verbs (`verdict`, `take`, `done`) never perform that transition today;
it stays an orchestrator-side concern. Not wiring this into `verdict accept`
itself — that is separate sibling work filed alongside this item under the
same decision (`f6jE_UJBu`). Not touching `merge_pull`/`post_review`/
`close_pull` — all three are plain REST already and unaffected by this
specific block.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
