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

Together the two environments show the boundary is not one-shape: an
environment can withhold a token entirely (ChatGPT Work), or expose one that
works but shares its quota with the connector/orchestrator layer already
calling GitHub on gitboard's behalf (Claude Code Remote) — so "a token is
present" is not by itself a reason to wire it in; the decision has to weigh
call-shape savings (caching, sha-guards, one atomic write instead of two
independently-agreeing call sites) against reopening a boundary that was
deliberately closed, tested, and documented as must-never-regress.

The security constraint matters in both cases: a solution must not scrape,
reveal, or copy connector/environment credentials into the shell, logs, or
anything the board pushes to its shared remote. It must use a supported
delegation or brokered interaction if direct token inheritance is
intentionally unavailable, and must never weaken `network_boundary_test.tl`'s
existing guarantees for the default (no-token-supplied) path.

## Change

Produce a short decision record that:

1. Documents the supported authentication capabilities available to a local
   `gitboard` process in EACH observed host environment (ChatGPT Work,
   Claude Code Remote, and any others worth checking), not just one.
2. Determines, per environment, whether a connector/token can safely broker
   the exact GitHub reads and writes gitboard needs — and where one can,
   whether doing so is actually worth it given a shared rate-limit identity —
   or whether gitboard should emit a machine-readable action for the
   orchestrator to execute and acknowledge instead.
3. Specifies ownership and verification for `sync`, `take --open`, `verdict`,
   and `done` when GitHub interaction crosses that boundary, for each
   supported environment shape.
4. Includes one end-to-end experiment per environment shape (a disposable
   branch or mocked transport where no live token exists; a scoped,
   non-persisted read where one does), without exposing credentials.
5. Separates product/environment work from repository changes and files any
   concrete implementation children in the correct place — explicitly
   including whether `network_boundary_test.tl`'s assertions need a new,
   narrowly-scoped exception for an explicit opt-in path, or whether they
   stay exactly as they are and the answer is "caller keeps doing this work."

## Non-goals

Do not request that connector or environment tokens be printed, logged, or
injected into arbitrary processes. Do not add another GitHub client, and do
not wire `_work/api.tl`'s production transport to any credential source,
before this decision record establishes which boundary is supported and
why — a token being technically usable in one environment is evidence for
this decision, not a green light to bypass it.
