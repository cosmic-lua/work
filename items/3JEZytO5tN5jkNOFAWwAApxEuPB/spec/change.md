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
