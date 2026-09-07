## Evidence

Two prior items already fixed the two earlier failure modes here:
`eWXR_dtJc` (completed, PR #70) made `verdict accept` record the
verdict FIRST and report a landing failure on the verdict line without
losing the judgment (`gitboard-verdict: accept on <id8>: awaiting
merge — landing failed (...), land it by hand`); `c77H_v0vS`
(completed, PR #31) added `merge_group:` to `board.yml` and got
`cosmic-lua/work`'s "Allow auto-merge" repo setting enabled. Both are
confirmed live and working as designed.

What remains, observed live across all 5 accepts this session
(2026-09-07, `cosmic-lua/cosmic` #1789/#1790/#1791, `cosmic-lua/work`
#78/#79): `verdict accept`'s own landing attempt — a REST merge PUT,
then GitHub's `enablePullRequestAutoMerge` GraphQL mutation as
fallback — gets a 403 SPECIFIC TO THE CALLING SESSION'S OWN TOKEN in
this environment: `This GraphQL query is not enabled for this session
— only the pinned set of PR-review operations is served. Use REST via
'gh api repos/{owner}/{repo}/...' instead.` This isn't the repo-level
gap `c77H_v0vS` fixed (auto-merge IS enabled — a DIFFERENT tool,
`mcp__github__enable_pr_auto_merge`, using this session's own broader
GitHub-connector credentials rather than gitboard's pinned release
binary's token, succeeded immediately, 5 for 5, in every case this
session hit the 403). It looks like a deliberate scope restriction on
what GraphQL operations gitboard's own pinned token is allowed to run
from a sandboxed/remote environment like this one — possibly not a
gitboard code bug at all, but an environment/proxy policy decision
gitboard's own request has no way to route around.

Every one of the 5 landings this session therefore needed a manual,
out-of-band step: call the orchestrating session's own GitHub tool
(`enable_pr_auto_merge`) after `verdict accept` reports "land it by
hand" — a real, correct, but undocumented recovery path that a session
without this one's prior discovery would have no way to find from
`help verdict`'s text alone.

## Change

Two things, whichever is true once investigated:

1. If gitboard CAN reach a working REST-only path here (e.g. `gh api
   repos/{owner}/{repo}/pulls/{n}` with a PATCH/PUT that doesn't
   require the GraphQL mutation the 403 names, as the error message
   itself suggests — "Use REST via `gh api`..."), fix the landing step
   to use it instead of the refused GraphQL call.
2. If no such path exists from gitboard's own pinned token in this
   class of environment, `help verdict`'s "falling back to auto-merge
   when GitHub refuses one directly" should say plainly that this
   fallback can itself be refused for session-scope reasons distinct
   from `c77H_v0vS`'s repo-setting gap, and name the recovery: the
   orchestrating session completes the landing with its own broader
   GitHub tool access, then nothing further is needed — `verdict`
   already recorded the judgment per `eWXR_dtJc`.

## Non-goals

Not re-litigating `eWXR_dtJc`'s record-first ordering or `c77H_v0vS`'s
repo-setting fix — both are confirmed working. Not proposing gitboard's
pinned token be granted broader GraphQL scope — that's an environment/
security decision outside this item.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
