## Evidence

The `cosmic --diff OLD` item handed over `11cdd43e`, received a semantic
request-changes verdict, and handed over correction `8b5299d5`.  The correction
added a field to `_cli.parse.Options`; the builder explicitly carried forward
the earlier cold-build result because the patch "only changes parser error
routing".  A fresh review then ran the spec-named
`_build/coldbuild_test.tl` and found that the pinned checker could not see the
new field.  The guard already existed and the original spec already named it;
the missing rule was that evidence belongs to one exact head.

This is not the ratchet case already covered by «215t_A5ZL»: no ratchet
tripped.  It is also not a reason for a reviewer to rerun the full gate, which
«xWSa_IIFM» correctly forbids.

## Change

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

## Non-goals

No new test runner, CI query, or durable evidence schema.  No requirement that
reviewers rerun `--make ci`.  No change to cosmic's cold-build test or any
product code.

## Access

cosmic-lua/work, read and write on a branch.  Read-only access to board history
for the cited item and completed countermeasures.

