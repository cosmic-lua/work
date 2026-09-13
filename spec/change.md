One source file and two test files, on the `board` branch.

**1. `_work/flow.tl` (490 lines — 10 of headroom, so the addition is
compact).** `built_by` compares names by their ROOT: the name up to
the first `/`, the whole name when it has none. A small local
`root(name: string): string` above `built_by`; the claim comparison
and the builders walk compare `root(x) == root(session)`. The doc
comment gains the rule: `/` is the wave separator — an orchestrator
mints per-agent claims as `<its own id>/<suffix>`, so everything under
one root is one session for review distance, while claim LOCKS
elsewhere stay exact-string and are untouched by this. A name with no
`/` roots to itself, so every existing identity (UUIDs,
GITBOARD_SESSION values, USER-HOSTNAME) behaves exactly as before.

**2. `_work/flow_test.tl` (197 lines) — `test_built_by_roots_names`:**
an item with `claim = "orch/3IVKVslE"` is built by `"orch"` and by
`"orch/anything"`, not by `"orchid"` (prefix means the `/` boundary,
not string prefix) and not by `"other"`; `builders = {"orch/a"}` after
the claim moved on answers the same; plain names still compare
exactly.

**3. `_work/action_test.tl` (grep `built_by` shows the reviewable walk
consults it) — one case:** a `check` item whose builders carry
`"orch/x"` is not offered as a review to session `"orch"` (skipped as
mine), and is offered to `"other"`.

Measured 2026-08-27 at board head: `wc -l _work/flow.tl` 490,
`_work/flow_test.tl` 197; `built_by` is flow.tl's only reader of
`builders`.
