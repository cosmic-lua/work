## Evidence

`f6jE_UJBu` (decision: GitHub auth and interaction boundary for gitboard
across host environments) found that `_work/api.tl`'s production transport
is hard-bound to `no_transport`, guarded by `_work/network_boundary_test.tl`,
which forbids `api.tl` from requiring `cosmic.env`, reading `GITHUB_TOKEN`/
`GH_TOKEN`, or wiring a live transport — introduced in "Redesign gitboard
around caller-owned Git transport" (`ae840934`, PR #90).

In a Claude Code Remote session (2026-09-12), `GITHUB_TOKEN`/`GH_TOKEN` ARE
present as plain environment variables and DO authenticate against
`api.github.com` (verified live: `GET /user` → 200, `login: whilp`). That
identity shares its rate-limit budget with the orchestrator's own separate
GitHub tool calls, so a token being present is not by itself a reason to use
it automatically — but it means an EXPLICIT, opt-in path to real GitHub
writes is technically available in at least this one environment, for a
caller that chooses to use it.

## Change

Add a narrow, explicit opt-in that lets a caller swap `_work/api.tl`'s
`M.transport` from `no_transport` to a real one, WITHOUT `api.tl` itself
ever scanning the ambient environment. Concretely: a caller-supplied env var
name (e.g. `GITBOARD_PROVIDER_TOKEN_ENV=VARNAME`), read only by a new, small,
separately-named entry point — never by `api.tl`'s default load path, never
by any of the verbs `network_boundary_test.tl` already covers (`take`,
`gitworktree`, `storeinit`, `format`). The caller states exactly which env
var carries the token; gitboard never guesses `GITHUB_TOKEN`/`GH_TOKEN` on
its own.

Extend `_work/network_boundary_test.tl` (or add a sibling test) asserting:
the DEFAULT path (no activation requested) still refuses exactly as today —
every existing assertion in that file keeps passing unmodified — and the new
opt-in path, exercised with a fake env var pointing at a fake token in a
test, wires a real-shaped transport without touching real ambient discovery
in the process.

## Non-goals

No verb's behavior changes yet — this item is transport plumbing only. Not
wiring `verdict`/`take`/any other verb to actually use the enabled transport
— that is separate sibling work, filed alongside this item under the same
decision (`f6jE_UJBu`). Not adding credential
storage, caching, or logging of the token value anywhere — it is read once,
used in-process, and never written to disk, the `o/` cache, or anything the
board pushes to its shared remote.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
