# D46 — the HTTP server engine is a cosmo.http binding over net/http; the surface is cosmic.http; htmx is a guide, not a coupling

## Goal

Record the settled tradeoff before the first line of server code, so
the children that follow build one design and nobody relitigates
"why not a pure-Teal server" or "why not redbean" in a PR comment.
The call has been made by the goal owner (2026-09-12): the core httpd
lives in cosmopolitan, leveraging its `net/http/` code — redbean
inverted — and its design should be ergonomic under htmx without being
coupled to it.

## Evidence

The decision has three real losers, which is what earns a record
(`skills/decide/SKILL.md`, "when a tradeoff earns a record"):

1. **A pure-Teal server over `cosmic.net`** — the shape
   `docs/guides/recipes.md:126-189` already teaches ("HTTP without a
   framework"). Loses on correctness surface: RFC 7230 header framing,
   the repeatable-header table, chunked decoding and the 400-ns parser
   are 86 files of tested C in `net/http/` (`ls net/http | grep -c .`
   → 86; `ls test/net/http/` has `parsehttpmessage_test.c` and
   `unchunk_test.c`), and re-deriving them in Teal duplicates a
   fuzzed parser with an unfuzzed one.
2. **Vendoring redbean as-is** — `tool/net/redbean.c` is 7314 lines
   (`wc -l`), a fork-per-connection server with its own Lua API
   (`GetHeader`/`SetHeader` at `tool/net/redbean.c:4089-4125`, gated by
   `OnlyCallDuringRequest`), global request state (`cpm`, `inbuf`),
   and a TLS stack on the retiring Mbed TLS 2.26 («nL8J_W71y»). The
   fork "was slimmed to the C core" (D9 context). Loses on ownership:
   cosmic would ship a second Lua API and a second concurrency model.
3. **A `cosmic.htmx` server** (the Go-framework shape: a server whose
   handler type knows `HX-Request`) — loses on the least-thing rule
   (`docs/goals.md`, "every solution is the least thing that holds
   these promises"): every non-htmx user pays for it, and htmx's whole
   contract is a dozen request/response headers a pure module can
   read and set.

D9 stands (direction, not deadline) and gets an amendment bullet: the
server story has started, the concurrency half remains open.

## Change

1. Write `docs/decisions/d46-http-engine-is-a-cosmo-binding.md`
   (next free number: `ls docs/decisions/ | tail -1` prints
   `d45-rank-is-a-list-position-at-every-level.md`). H1 exactly:
   `# D46 — the HTTP server engine is a cosmo.http binding over net/http; the surface is cosmic.http; htmx is a guide, not a coupling`.
   Header `date: 2026-09`, `status: active`. The four sections, with
   the three rejected options above each carrying its reason, and
   consequences naming: (a) a `cosmo.http` contract is frozen at the C
   boundary per cosmopolitan's AGENTS.md (a change needs
   `definitions.lua` in the same commit and a cosmic regen as its own
   PR); (b) `cosmic.http` v1 is single-connection-at-a-time, keep-alive
   within a connection — the concurrency model is a later decision,
   and `serve` must be shaped so that decision does not change the
   handler signature; (c) `cosmic.http` never reads an `HX-*` header;
   `cosmic.htmx` is pure functions over `http.Request`/`http.Response`;
   (d) what would make us revisit: an engine need `net/http/` cannot
   serve (HTTP/2) or a second consumer of the binding with an
   incompatible message shape.
2. Amend D9: append
   `- **amended 2026-09 (D46 starts the server half):** ...` and set
   `status: amended 2026-09 (D46 started the server story)`; the
   concurrency story stays open.
3. `bin/cosmic _docs/derive.tl` to rewrite the index table in
   `docs/decisions/README.md`; `bin/cosmic --make test
   _build/docs_test.tl` green; `bin/cosmic --make ci` ends `ci: PASS`.

Do not touch `docs/goals.md` (G7's rank and activation are the owner's
call — `gitboard help system`) and do not touch
`docs/guides/recipes.md` (the recipe stays true until `cosmic.http`
ships; the core child rewrites it).

## Non-goals

- No code. No `cosmic/http/`. No change to `cosmo.*`.
- Not the concurrency decision.

## Access

- cosmic-lua/cosmic: read+write (`docs/decisions/`).
- cosmic-lua/cosmopolitan: read-only (citations).
