## Question

How should `gitboard` perform GitHub reads and writes across the different
host environments it runs in, given each grants (or withholds) local GitHub
credentials differently — and, where a token IS available, given it may share
its rate-limit identity with the very orchestrator calls it would replace?

## Evidence

Measured 2026-09-07 in a ChatGPT Work session while completing `1QjU_Fdth`:

- GitHub operations were available through the authenticated connector.
- `gitboard sync` printed `lanes: unknown (release.yml: no GitHub token: set
  GITHUB_TOKEN (or GH_TOKEN))`.
- The local environment had no token usable by `_work/api.tl`, so integrated
  operations such as PR inspection/landing could not use their intended path.
- PR #85 had already merged, so the session used connector facts and then a
  local board transition to repair the stranded accepted item.
- Current `gitboard` already implements `take --open`, verdict-driven GitHub
  review/landing, cached reads, and already-merged handling. This is therefore
  not a missing-verb or stale-pin problem; it is an authentication/capability
  boundary between an app connector and a child process.

Measured 2026-09-12 in a Claude Code Remote session, the opposite shape:

- `GITHUB_TOKEN` and `GH_TOKEN` ARE present as plain environment variables —
  confirmed with a live `GET https://api.github.com/user` bearer-token call
  returning `200`, `login: whilp`.
- That login is the SAME identity the session's separate GitHub MCP-tool
  calls (`mcp__github__*`) already act as — and that identity had just hit
  GitHub's secondary abuse-detection rate limit on `update_pull_request`/
  `enable_pr_auto_merge` calls from those same MCP tools, moments earlier in
  the same session. A token being present here does NOT imply a separate
  rate-limit pool; it is the same budget the orchestrator's own calls spend.
- `_work/api.tl`'s production transport is hard-bound to `no_transport`
  ("GitHub transport is external to gitboard"), guarded by a dedicated
  static test (`_work/network_boundary_test.tl`) that forbids `api.tl` from
  requiring `cosmic.env`, reading `GITHUB_TOKEN`/`GH_TOKEN`, or wiring a live
  transport, and forbids `gittake.tl` from even requiring `_work.gh` — introduced
  wholesale in "Redesign gitboard around caller-owned Git transport" (`ae840934`,
  PR #90), a deliberate, large, tested pivot, not an oversight.
- `_work/ghwrite.tl` (write) and `_work/gh.tl`/`_work/api.tl` (read) already
  implement real logic behind that wall — sha-guarded `merge_pull` (a moved
  head 409s instead of merging unreviewed code), a one-shot GraphQL
  `enable_auto_merge`, own-PR-aware `post_review` (falls back to `COMMENT`
  where GitHub refuses `REQUEST_CHANGES` on the token's own PR), ETag-cached
  reads, and persisted rate-limit-header tracking meant to let a caller back
  off before a refusal rather than after one. None of it runs outside its own
  unit tests today; `ghwrite.tl` is required only by `ghwrite_test.tl`.
- Board item `3nAe_st3T` (completed, 2026-09-07) had already found the live
  cause of the redesign's timing: `verdict accept`'s own landing attempt, on
  the code as it existed THAT DAY, got a 403 SPECIFIC to the calling session
  attempting GitHub's `enablePullRequestAutoMerge` GraphQL mutation, while a
  different tool using the orchestrating session's own broader credentials
  succeeded immediately every time. "Redesign gitboard around caller-owned
  Git transport" landed less than 11 hours after that item completed.
- Reproduced directly, 2026-09-12: a raw GraphQL call (even a trivial read)
  returns HTTP 403 from an Anthropic-operated proxy: `"GitHub GraphQL is not
  available from Claude Code sessions; use the REST API... For review
  threads, auto-merge, and draft/ready-for-review use the CCR routes on
  api.github.com: ... PUT or DELETE /repos/{owner}/{repo}/pulls/{n}/ccr/auto_merge
  ..."`. Verified live and working end-to-end on a disposable PR
  (`cosmic-lua/work#138`, opened, probed, closed without merging):
  `POST .../ccr/ready_for_review` → `200 {"draft":false}`; `PUT
  .../ccr/auto_merge` → `200 {"enabled":true,...}`; `DELETE .../ccr/auto_merge`
  → `200 {"enabled":false}`; `GET .../ccr/review_threads` → `200 []`. A plain
  REST merge attempt on the same PR got an ordinary GitHub 405 ("Changes must
  be made through the merge queue") — ghwrite's own documented auto-merge
  trigger, not a Claude-specific refusal. Plain REST (`merge_pull`,
  `post_review`, `close_pull`) is unaffected by the GraphQL block; only
  `enable_auto_merge` needs a fallback.

Together the two environments show the boundary is not one-shape: an
environment can withhold a token entirely (ChatGPT Work), or expose one that
works but shares its quota with the connector/orchestrator layer already
calling GitHub on gitboard's behalf, AND blocks GraphQL specifically while
offering a documented REST substitute for exactly the one write that needs
it (Claude Code Remote).

The security constraint matters in both cases: a solution must not scrape,
reveal, or copy connector/environment credentials into the shell, logs, or
anything the board pushes to its shared remote. It must use a supported
delegation or brokered interaction if direct token inheritance is
intentionally unavailable, and must never weaken `network_boundary_test.tl`'s
existing guarantees for the default (no-token-supplied) path.

## Decision

Enable gitboard's already-implemented provider transport for the Claude Code
Remote shape specifically, through an explicit, non-ambient opt-in — never
by changing any verb's default behavior, and never by weakening
`network_boundary_test.tl`'s existing guarantees for a caller that does not
opt in. ChatGPT Work (no token at all) gets no change: the caller keeps
doing this work there, exactly as `1QjU_Fdth` already established. Any
future environment gets evaluated the same way this one was — measure what
credential and API shape it actually offers before assuming either "no
token" or "token behaves like a normal PAT."

Filed as three sibling `role: work` children of this decision, in dependency
order:

1. `BM00_etFW` — the opt-in transport-activation plumbing itself (no verb
   behavior changes).
2. `SH8f_KuHG` — `ghwrite.enable_auto_merge`'s CCR-route fallback for the
   one write GraphQL cannot reach here (depends on 1 only for reachability;
   the fallback logic is unit-testable today via the existing fake
   transport).
3. `IXiQ_JbjO` — wiring `verdict accept`'s landing sequence to use `ghwrite`
   when the opt-in is active, restoring what `eWXR_dtJc`/`c77H_v0vS` already
   proved correct before the redesign, strictly behind the new opt-in this
   time (depends on 1 and 2).

None of the three is a green light on its own: each still needs its own
build, fresh-context review, and mutation-tested proof exactly like any
other item on this board — this decision authorizes the DIRECTION, not a
bypass of the process that would normally gate a change to a
security-relevant boundary.

## Non-goals

Do not request that connector or environment tokens be printed, logged, or
injected into arbitrary processes. Do not wire `_work/api.tl`'s production
transport to any credential source, or change any verb's default behavior,
outside the three filed children above — this decision is the authorization
for that specific, scoped follow-through, not a blanket license to touch
the boundary anywhere else.
