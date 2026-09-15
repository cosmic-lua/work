# Snapshot review follow-up validation

PR #173 review follow-up, 2026-09-15. The implementation tested here is
`60ced5f000f754ae6ce1bf86acda52f2108e1135`; the subsequent evidence commit
only adds this record. Earlier adapter-based runs are historical evidence
in `SNAPSHOT_PUBLICATION_EVIDENCE.md`.

## Repository gate

The complete local `COSMIC_JOBS=4 bin/cosmic --make ci` passed: formatting,
strict checking, lint, 1,077 tests across 162 files, and 86.4% coverage.
The standalone build passed for 344 Teal files and one binary. Coverage
floors and test timeouts were unchanged. An interrupted gate was resumed
from its existing build outputs and completed successfully.

Each solo implementation stage also passed its focused tests and static
checks. The final shared-rule stage passed 85 tests across 11 files.

## Regression and mutation checks

Eleven separate compiling guard mutations failed their targeted runtime
assertions, with the restored controls passing:

- Re-parenting stale composition after another clone publishes and refreshes.
- Omitting durable arming before the real shell push.
- Removing the exact push lease while a pre-push hook rewinds the remote.
- Substituting the local commit for the saved provider candidate.
- Skipping live authority revalidation after a clock rollback.
- Skipping the fresh claim-clock check after a clock rollback.
- Dropping first-parent traversal from saved-candidate reconciliation.
- Dropping first-parent traversal from cleaned-attempt discovery.
- Accepting a mixed item-and-claim snapshot.
- Accepting an undeclared board path.
- Accepting an otherwise-valid snapshot against the wrong supplied parent.

Migration evidence mutation is also refused by a regression. No semantic
mutation kill is claimed for deleting one overlapping migration guard
while another still refuses the same input.

Additional public regressions cover frozen summaries, canonical start,
draft-selector refusals, malformed and orphaned recovery reads, record-only
abandonment, destination/mode changes, local auto-confirm, and native/raw
readiness and research-completion parity.

## Focused performance comparison

Separate local runs used `COSMIC_JOBS=4` and the same three test files:

| Fixture | Before review fixes | After review fixes |
|---|---:|---:|
| snapshot integration | 15.477 s | 6.060 s |
| preparation receipt flow | 72.260 s | 21.370 s |
| worktree adoption authority | 94.381 s | 26.658 s |

These are fixture timings, not controlled microbenchmarks or hosted-runner
guarantees. The retired receipt test reduced the combined count from 29
to 28; the other two file counts stayed the same. The changes reuse full
preflight results with fresh authority checks, decoded final views for
fsck, and before/after views for graph gates. The entire final board still
receives canonical validation; no persistent cache or trusted-parent
shortcut was added.

## Direct ChatGPT Work exercise

The final standalone binary used the Teal JSON protocol directly with the
installed GitHub connector tools. No JavaScript runner or bridge was used.
All test writes targeted the existing isolated branch
`validation/gitboard-snapshot-20260914` in `cosmic-lua/work`.

Ordinary title edits, an edit/revert pair, and a summary produced local
commit `c75f9f0dd76055ba8791cfe112ec860ea450c8aa` with sole parent
`86a8030652d0fdd8e45df53aaa4b66e7d1db8ced`. Exactly three connector writes
created the tree, created the provider commit, and advanced the isolated
branch without force. The returned tree was exactly
`cff4ce009bca7317bef3d9a4e6f3b057e2ac8205`; the provider commit was
`176f0b2bbd3e54d6adf4f644d9da8c4b96141b9d`.

Before advancing the ref, an independent check read both candidate and
updating sidecars and found that exact provider SHA durably recorded.
The destination head was freshly observed and checked against the parent.

After fetching and reconciling, the confirming response was deliberately
discarded. Recovery sidecars and the proposal ref were verified absent.
Restarting the same local commit discovered and confirmed the exact
provider commit with **zero additional connector writes**. Both preflight
issue lists were empty, and only the affected synthetic item was reported.

The production board was maintained with the pre-change binary throughout;
candidate implementation code was exercised only on the isolated board.
