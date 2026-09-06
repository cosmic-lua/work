## Evidence

Two orchestrator sessions worked this board at once on 2026-09-06
(f6f470de and a36d13ac). `gitboard show`'s doing rows print the
BUILDER's claim and the PR (`[review] @build-QYqs_nEsq-f6f470de pr:46`)
but not the reviewer's claim, so an orchestrator learns a review is
already held only by trying `take`: four refusals in a row ("3Ixaa1nI
is under review by review-QYqs_nEsq-a36d13ac — take over a live review
with --force --why"), one per pending PR, plus one lost push race. The
items table already carries `reviewer` (`_work/readddl.tl`, column
`reviewer TEXT`), and `take` reads it for the refusal.

`wc -l _work/gitview.tl` → 497 (3 under the cap — cosmic-lua/work#45
left it alone for that reason; «duSw_TyDF»'s in-flight change moves
`id_line` out if it must).

## Change

`_work/gitview.tl`, the doing-row renderer: when an item's `reviewer`
is non-empty, append ` reviewer:<session>` after the `pr:N` mark, so a
row reads `[review] @build-QYqs_nEsq-f6f470de pr:46
reviewer:review-QYqs_nEsq-a36d13ac`. Keep the file under 500: if the
line does not fit, move `id_line` and its doc comment to
`_work/tail.tl` first (the same relocation «duSw_TyDF» names — whichever
lands second rebases onto it). `_work/gitview_test.tl` (or wherever
doing rows are asserted — `grep -n 'pr:' _work/*_test.tl`): one row with
a reviewer prints it, one without prints nothing extra.

`gitboard help orchestrate`, the review fan-out bullet: "a doing row
carrying `reviewer:` is already claimed — skip it, never `--force`."

## Non-goals

No change to `take`'s refusal text or the lock itself.
