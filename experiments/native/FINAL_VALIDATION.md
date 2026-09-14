# Integrated format-6 validation — 2026-09-14 UTC

The full repository gate passed with the pinned Cosmic runtime:

| Check | Result |
| --- | --- |
| Tests | 1,056/1,056 passed |
| Coverage | 87.1%, 14,681/16,846 lines; 157 test files |
| Strict types and formatting | Passed, 340 files |
| Lint | Passed, 371 files |
| Full CI | Passed, all four stages |
| Semantic campaigns | 70/70 killed; every baseline and restored control passed |
| Fresh independent source review | No functional blockers through `fa3d45cd4` |

The gate used `COSMIC_JOBS=2` and unchanged test timeouts. An earlier overloaded
coverage run had seven timeouts; isolated runs and this full rerun passed.
Two stale expectations from that run were corrected before the final gate.
The pristine runtime SHA-256 matched `bin/cosmic.pin`:
`dd6b44b09590b196eee9654fbb9b3a14baa4ba943d8527a2903b1a16573b18ea`.

[Mutation evidence](MUTATIONS.md) identifies each campaign's exact source and
substitutions. A separate advanced-draft sentinel covers prefix consumption and
crash ordering; a focused current-source run revalidates message matching after
the prefix refactor. All 70 current catalog substitutions match exactly once.

[Actual Work connector execution](VALIDATION.md) published a two-commit draft,
acquired a claim, and deleted it using 11 exact v3 tool calls on the dedicated
validation branch. All fetched receipts confirmed and all planned trees matched.
The claim's current authority changed from absent to active to absent.

[Full-board migration](MIGRATION_VALIDATION.md) replayed 13,760 events, retained
1,946 source refs in its witness, reported zero fsck problems and restarted
identically. Cold and warm read proofs each projected the 1,430-item board once
and its complete history once despite 4,290 loads plus resolutions and spec reads.

[Fresh review](REVIEW.md) covers the final native source, including publication
recovery, dependency races, claim/handover contracts, archive checks and cache
isolation. Owner approval, release, production activation and consumer pinning
remain separate; no production board ref or ruleset changed during this work.
