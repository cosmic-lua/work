## Current refinement — native Cosmic reuse review

This refinement supersedes conflicting implementation assumptions in the historical spec below; its original evidence is retained for context.

The proposed `scan_values`/ROUND_CONTEXT-blanking mutation targets historical code: current `_work/brief.tl` at a43d1824cd5d48408b780f2ac16a3b42e0c5cd38 has no `scan_values` and initializes ROUND_CONTEXT explicitly. Reproduce the user-visible literal-data contract against the current code before selecting a meaningful mutation. Preserve review prose containing `<CONST_NAME>` and `{{.field}}` verbatim, without reporting those data tokens as missing fields. Feed these regression cases into work#103 (https://github.com/cosmic-lua/work/issues/103) and Cosmic#1809 (https://github.com/cosmic-lua/cosmic/issues/1809); do not reinstate an obsolete scanning mechanism to satisfy the old mutation instruction.

## Evidence

work#69's reviewer removed the `out["ROUND_CONTEXT"] = ""` blanking in `_work/brief.tl`'s `scan_values` — the line that stops a round-1 review body containing `<UPPER_SNAKE>`-shaped prose (a finding that says "rename to `<CONST_NAME>`") from being reported as an unfilled placeholder — and `bin/cosmic --make test _work/brief_rework_test.tl` stayed 11/11 green. The builder-side twin has its own case (`test_builder_rework_brief_does_not_mistake_review_prose_for_a_placeholder`); the review-side has none, so the blanking is decoration to the gate today.

## Change

`_work/brief_rework_test.tl`: one case beside the builder-side one — a rework item whose recorded round-1 review body contains a literal `<CONST_NAME>` — asserting `brief review` renders it verbatim inside the round context and reports no unfilled placeholder. Removing the `ROUND_CONTEXT` blanking must fail it.

## Non-goals

No change to `brief.tl`'s behaviour.

## Access

cosmic-lua/work, read and write on a branch; cosmic-lua/cosmic, read-only for the linked typed-template migration context; no other repository.

## Ready when

The new case passes on main and fails with the `out["ROUND_CONTEXT"] = ""` line removed.

