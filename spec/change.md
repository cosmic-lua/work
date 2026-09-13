Ask before merging. Three files on the board branch, measured 2026-08-19:

1. **`_work/review.tl`** (82-line test file beside it; the `Pull` record
   is lines 11–19 and has no `merged` field — `grep -c merged
   _work/review.tl` is 0): add field `--- Already merged, by any route.`
   `merged: boolean` to `record Pull`.
2. **`_work/gh.tl`** (190 lines): in `pull()` (lines 43–70), parse it —
   `merged = v["merged"] == true` — beside the existing `draft` parse.
3. **`_work/gitland.tl`** (69 lines, well under cap): in `cmd_land`,
   after the `it.pr == 0` refusal and before `gh.merge`, fetch the PR:
   `local p, perr = gh.pull(s, it.pr)`. When the fetch fails, refuse with
   `("cannot read PR #%d: %s"):format(it.pr, perr)` — land already needs
   the API for the PUT, so a GET failure is the same wall named earlier.
   When `p.merged` is true, print
   `("gitboard-land: PR #%d was already merged"):format(it.pr)` and fall
   through to the existing `verbs.cmd_done(s, id, "completed", force,
   why)` — the commit trail's existing `done ID completed (from land)`
   line is what distinguishes a landing, and this path now earns it.
   When `p.merged` is false, proceed to `gh.merge` exactly as today.

The race window — a PR merged between the GET and the PUT — needs no new
classification: the PUT fails with the generic ERROR text, and the
re-run land's GET now answers merged and ends the item. Self-healing on
retry beats a second classifier.
