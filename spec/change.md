Settled per the owner decision; measured 2026-08-19 at `f420391`.

`_tool/coverage/baseline.tl` (424 lines):

1. **Delete the never-raise rule.** `render`'s floor clamp (lines
   82–84: keep `was` when the fresh pct is higher) goes, and `text_for`
   (line ~338) stops threading `previous` into `render` for clamping —
   the fresh measurement is the row. `lowered()` (line 366) STAYS: it is
   the visibility half, and now narrates both directions — extend its
   `note` to emit raises too (`%s %.1f%% -> %.1f%%` reads either way),
   so the rewrite's stderr names every row that moved.
2. **The corpus guard — breadth, not magnitude.** Before writing, when
   a committed floor exists: count the rows the rewrite would LOWER
   (the `lowered()` machinery already computes this). When MORE THAN
   HALF of the floor's rows would drop, refuse:
   `coverage --baseline REFUSED: this run would lower N of M floor rows
   — that is a measurement problem, not a decision. Run
   'bin/cosmic --make test' first so every .cov is fresh; a genuine
   project-wide decline is accepted by deleting .cosmic-coverage and
   starting the floor again.` A majority-lowering rewrite was the
   observed failure (140 problems, 73.5% -> 14.9%, twice on 2026-08-17);
   a deliberate broad decline keeps the explicit, diff-visible escape
   the message names. No tolerance knobs, no magic percentage.
3. **Tests** (`_tool/coverage/baseline_test.tl`, 484 lines — the
   parser-test deletions in 3I1J9Xhg are what make room, another reason
   for the blocked_by below): a wrongly-low row raises back on regen
   and the raise is narrated; a partial corpus (floor of 4 rows, fresh
   data lowering 3) refuses with the count; a fresh run lowering 1 of 4
   writes and narrates it; no-floor first run still writes.
