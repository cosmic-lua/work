In the rework-builder portion of `_work/brieftext.tl`, state that every
request-changes correction creates a new candidate head and invalidates prior
verification evidence.  Before handover, the rework builder must:

1. add or identify the focused regression for the reported finding;
2. diff the rejected head against the new head and name the boundaries that
   correction crosses; and
3. rerun every acceptance/guard command explicitly named by the item spec,
   even when the correction appears unrelated.

The brief must forbid claims such as "the prior cold-build remains green" for
a new head.  It should continue to prefer focused guards over repeated broad
gates.  Add assertions in the existing brief-template tests for the exact-head
rule, correction-diff audit, and spec-named guard rerun.

Keep this to `_work/brieftext.tl` and its existing template test file(s), at
most three files and 90 changed lines.  Bounce rather than changing board
state, CI integration, or product repositories.
