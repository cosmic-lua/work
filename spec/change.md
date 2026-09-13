1. In `_work/gh.tl`, add a read for a PR's review comments — GitHub's
   `GET /repos/{owner}/{repo}/pulls/{number}/reviews` (each review
   carries `state`, `body`, `submitted_at`) — following the existing
   `pull`/`checks` calls' shape (through `_work/api.tl`'s cached GET,
   same error-string convention, `s`/`repo` args identical to
   `head_checks`).
2. In `_work/brief.tl`'s `cmd_brief`, when `kind == "builder"` and the
   item's own `it.verdict == "request changes"` and `it.pr ~= 0`:
   fetch that PR's reviews via the new call, select the MOST RECENT
   review carrying `state == "CHANGES_REQUESTED"` (matching what the
   orchestrator has hand-picked in both occurrences above — the
   latest round's finding, not every round's), and fill
   `<BOUNCE_CONTEXT>` with a templated section quoting its `body`
   verbatim, plus a worktree-reuse paragraph keyed off the item's
   branch (`it.id:sub(1, 8)`, matching the existing `BRANCH` fill) —
   confirm the worktree exists and is clean and at the pushed head,
   do not branch fresh, do not discard the diff — and a push/no-new-PR
   instruction. A read failure (no reviews found, no token, a network
   error) leaves `<BOUNCE_CONTEXT>` unfilled exactly as today, so the
   brief still emits and the verdict line still names it as a
   placeholder the caller must fill by hand — this is a strict
   improvement over today's always-empty case, never a new failure
   mode.
3. Add or extend `_work/brieftext.tl`'s `BUILDER` template (or a
   sibling constant filled only in the rework branch) with the
   `<BOUNCE_CONTEXT>` section shape and the worktree-reuse/push
   paragraph, following the same `<UPPER_SNAKE>` fill grammar
   `_work/brief.tl:94`'s `fill` already implements.
4. Tests in `_work/brief_test.tl`: a rework item (verdict set, pr set,
   a fixture review fetch) produces a filled `<BOUNCE_CONTEXT>`
   quoting the selected review's body and a filled worktree-reuse
   section; a fresh item (no verdict) is unaffected — the existing
   fresh-pull brief tests must still pass unchanged; a rework item
   with multiple CHANGES_REQUESTED reviews selects the most recent by
   `submitted_at`, not the first.
