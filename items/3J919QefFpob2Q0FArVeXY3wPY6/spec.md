## Evidence

`gitboard help orchestrate` and every `brief KIND ID` verdict line
("claim it as `build-<handle>-<orch8>`") read as though that printed
string is the value `claim --session`/`done --session`/etc. expect.
It is not — `claim`, `done`, `drop`, and `worktree` all refuse anything
but a 32-hex id minted by `gitboard session new`
(`REFUSED: a claim needs a minted 32-hex session id — run 'gitboard
session new' and pass --session or set GITBOARD_SESSION`).

Reproduced live on 2026-09-10 orchestrating a 5-item build wave: five
separate `claim ID --session build-<handle>-ff5e70a9 ...` calls all hit
this refusal before the real workflow (mint a 32-hex session per item
with `gitboard session new`, using the printed label only as a
bookkeeping name) was worked out by trial and error. Also observed:
`brief builder ID --session <32-hex>` itself refuses unless a
`--receipt FILE` is also given ("--session requires a builder
--receipt"), while omitting `--session` entirely succeeds and reads
the claim already on record — an asymmetry not documented anywhere in
`help brief`.

Cost: one failed `claim` call per item (5 in this wave) plus the
investigation time to notice the mismatch, before landing on
`session new` per item as the actual mechanism.
