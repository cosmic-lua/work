## Evidence

work#69's reviewer removed the `out["ROUND_CONTEXT"] = ""` blanking in `_work/brief.tl`'s `scan_values` — the line that stops a round-1 review body containing `<UPPER_SNAKE>`-shaped prose (a finding that says "rename to `<CONST_NAME>`") from being reported as an unfilled placeholder — and `bin/cosmic --make test _work/brief_rework_test.tl` stayed 11/11 green. The builder-side twin has its own case (`test_builder_rework_brief_does_not_mistake_review_prose_for_a_placeholder`); the review-side has none, so the blanking is decoration to the gate today.

## Change

`_work/brief_rework_test.tl`: one case beside the builder-side one — a rework item whose recorded round-1 review body contains a literal `<CONST_NAME>` — asserting `brief review` renders it verbatim inside the round context and reports no unfilled placeholder. Removing the `ROUND_CONTEXT` blanking must fail it.

## Non-goals

No change to `brief.tl`'s behaviour.

## Access

cosmic-lua/work, read and write on a branch; no other repository.

## Ready when

The new case passes on main and fails with the `out["ROUND_CONTEXT"] = ""` line removed.
