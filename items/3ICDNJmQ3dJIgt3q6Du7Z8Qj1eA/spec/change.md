Three files. The decision is a PURE classifier so it is testable
without a network, the way `blocks_check`, `blocks_on_ci` and
`blocks_accept` already are.

1. **`_work/review.tl` gains `blocks_land(p: Pull, verdict_head:
   string): string`** — the refusal a landing earns, nil when the
   merge may proceed. It returns nil when `verdict_head` is `""` (an
   item accepted before the field was written has nothing to compare,
   and refusing those would strand them). It refuses when
   `verdict_head ~= p.head_sha`:
   `PR #N has moved since the accept — judged HEAD7, now HEAD7; re-review the current head or --force`
   with both shas at 7 characters. `wc -l < _work/review.tl` is 123.

2. **`_work/gh.tl`'s `merge` takes the head sha** and sends it:
   `merge(s, number, repo, sha)` → `{merge_method = "squash", sha =
   sha}` when `sha ~= ""`, and exactly today's body when it is `""`.
   GitHub answers **409** when the head has moved, so `refusal` gains
   a 409 branch naming that specifically — the guard is what makes
   409 reachable, so classifying it belongs in this slice:
   `REFUSED (409: PR #N moved between the accept and the merge and nothing was merged; re-review the current head)`.
   405 and the rest keep today's generic branch (a separate seam,
   noted below). `wc -l < _work/gh.tl` is 205.

3. **`_work/gitland.tl` wires both.** Before the merge, call
   `review.blocks_land(p, it.verdict_head)` and, unless `--force`,
   return `gate.verdict_line("land", false, "REFUSED: " .. refusal)`.
   Pass `it.verdict_head` to `gh.merge`. On the already-merged branch,
   do NOT refuse — the merge cannot be undone and refusing would
   strand the item forever — but when `blocks_land` would have fired,
   print
   `gitboard-land: WARNING PR #N merged at HEAD7 but the accept judged HEAD7`
   before ending the item, so the discrepancy is in the log rather
   than nowhere. `wc -l < _work/gitland.tl` is 85.

4. **Tests.** `_work/review_test.tl` (107 lines) gains
   `test_blocks_land_compares_the_accepted_head`: equal shas (nil),
   differing shas (refusal naming both), and an empty `verdict_head`
   (nil). `_work/gh_test.tl` (46 lines) gains a 409 case to
   `refusal`, asserting it is distinct from both the 403 wall and the
   generic branch.
