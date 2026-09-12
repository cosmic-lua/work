## Change

Add `_make/deps_projection_test.tl` with the exact contract and cache
lifecycle fixtures specified in parent W2CS_hqfO. This is a test-only PR
against current `deps.closure`; no optimization or exported production
seam. Keep existing tests in `_make/deps_test.tl` intact.

## Access

cosmic-lua/cosmic (main), cosmic-lua/work (parent specification supplied
by the orchestrator).

## Implementation

Read parent `## Fixed implementation contract` and `## Verification
specification`. Use `_make/deps_test.tl:23` (`local function fixture`)
as the filesystem setup pattern. Cover exact order, self exclusion,
cycles/diamonds, duplicate imports, external modules, declaration/runtime
twins, result array independence, and every cache identity transition.
Construct real small module files, scan once, and reuse the SAME index
inside each sweep. Reorder a copied Project.files array only before that
snapshot is first used. Use a new Project for each distinct snapshot.

For generated graphs, a small fixed-seed generator owns an explicit
adjacency table. Serialize that table as literal requires into temporary
source files. The independent oracle runs a local visited BFS over the
generator table then scans the fixture's project order; never calls the
production graph walker. Include N=64 reach counts 8/9 and N below 8.
Do not demand timing ratios in correctness tests. Clean fixtures through
cosmic.fs and use top-level test_* runner registration. No new public
type, cast, lint exemption, or coverage-floor change.

## Acceptance

All fixtures pass BEFORE the optimization via the repository's runner,
including existing `_make/deps_test.tl` and `_make/closure_test.tl`.
New file remains below 500 lines; aim for one <=300-line test addition.
Record exact runner commands/verdicts on this item. If a fixture asserts
behavior that the current implementation does not provide, reconcile it
against the parent contract before changing production code.
