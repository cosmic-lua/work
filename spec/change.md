Split `_work/store.tl` so the persistence layer stops living at the
lint cap. Re-measured 2026-08-29 (`wc -l`, post wave-11): store.tl is
EXACTLY 500 — the one file still at the cap (the original prose also
named flow.tl at 500; the two-state rewrite resolved that — flow.tl is
379 now). Next-nearest: gitverbs.tl 493, converge_test.tl 423. The
history of HOW files reach the cap (two overlapping PRs whose
line-count predictions were each right alone) is in this sidecar's
earlier prose below and stands as the rationale: a split that leaves
real headroom, not a prose trim that resets the trap.

The seam, measured (`grep -n "^local function" _work/store.tl`): lines
282-448 are the remote/CAS/log half — `has_origin`,
`conflicted_items`, `rebase_onto_remote`, `sync`, `publish`,
`history`, `touched_at` — while 52-281 are local persistence (`git`,
`git_ok`, `open`, paths, `load_item`, `resolve`, `read_spec`, `list`,
`stage`, `save`).

1. New `_work/publish.tl` receives the seven remote/log functions
   verbatim (no behavior change — this is a move). The `Store` record
   and the `git`/`git_ok` plumbing stay in store.tl; export `git` and
   `git_ok` from store's module table so publish.tl calls them
   through `store.` (they already take `Store` as arg 1, so no
   signature moves). The `Event` record moves with `history`.
2. Callers update imports mechanically: measure with
   `grep -rln "store\.\(sync\|publish\|history\|rebase_onto_remote\|has_origin\|touched_at\|conflicted_items\)" _work/ | grep -v _test`
   and change each site to `publish.<fn>`; same sweep over the tests.
   No call-site logic changes.
3. Both halves must land with ≥60 lines of headroom — the reviewer
   measures with `wc -l`; the lint gate enforces the cap itself.
4. Coverage: moving lines makes the ratchet see a new file — if the
   gate demands it, regenerate with `--make coverage --baseline` in
   the same diff (never hand-edit), and the baseline diff must be
   row-moves only, no floor lowered.
