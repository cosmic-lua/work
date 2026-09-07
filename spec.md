## Evidence

`gitboard verdict ID accept` lands a product-repo PR itself via a
GraphQL mutation, falling back to auto-merge "when GitHub refuses one
directly" (per `help verdict`). In this session, EVERY accept against
both product repos (`cosmic-lua/cosmic` #1789/#1790/#1791,
`cosmic-lua/work` #78/#79 — 5 for 5) hit the same failure instead of
that fallback: `POST /graphql: HTTP 403: This GraphQL query is not
enabled for this session — only the pinned set of PR-review operations
is served. Use REST via 'gh api repos/{owner}/{repo}/...' instead.`
Every one required landing "by hand": a plain REST merge
(`PUT .../pulls/N/merge`) then failed too, but differently — `405
Repository rule violations found / Changes must be made through the
merge queue` — on every repo tried, because both repos require a merge
queue. Only `enable_pr_auto_merge` (GitHub's GraphQL
`enablePullRequestAutoMerge` mutation via a different token/session
path than gitboard's own) actually worked, in all 5 cases.

So the documented fallback ("auto-merge when GitHub refuses one
directly") never fired here: gitboard's own landing code hit the
GraphQL 403 before it ever got a chance to try a REST auto-merge path,
and even a direct REST merge attempt would have failed anyway on a
merge-queue-protected repo — auto-merge-enable is the only verb that
succeeds against a merge-queue repo, and gitboard's fallback doesn't
reach for it.

## Change

`gitboard verdict ID accept`'s landing step: when the GraphQL merge
mutation is refused (403, or any auth/permission error — not a
merge-conflict or check-failure refusal), retry via the REST
auto-merge-enable endpoint (`PUT
/repos/{owner}/{repo}/pulls/{n}/merge` is the wrong verb for a
merge-queue repo; the corresponding REST equivalent of
`enablePullRequestAutoMerge` — or shelling to `gh pr merge --auto` — is
what actually succeeds) rather than only a direct-merge REST retry.
`help verdict`'s "falling back to auto-merge when GitHub refuses one
directly" should describe this REST path concretely, including the
merge-queue case, since that's the actual repeated failure mode, not a
rare edge.

## Non-goals

Not changing `--no-land`'s existing "record only" behavior for a repo
the token cannot merge at all. Not adding merge-queue detection ahead
of time (checking repo rules before attempting) — reacting to the
actual refusal is simpler and already how the existing fallback is
framed.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
