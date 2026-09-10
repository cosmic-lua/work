## Evidence

Board item `3J6saJCITVTaxdaDZizcsdSXEQu` passed the spec bar as one build, but its
five Change bullets combined independently reviewable work in process supervision,
result persistence, capability taxonomy, build-cache invalidation, CI policy, test
migration, and documentation. The first handed-over implementation
(`bf2b44d30bebc18190009d1ec8229e17f0dd6ad5`) changed 33 files, added 1,056 lines,
and created six modules. Its fresh-context review found two P1 defects in the process
supervisor plus a malformed-result crash. The builder did not bounce before editing
because neither the spec bar nor the builder brief states a scope budget or a
mandatory pre-edit decomposition check.

`gitboard find 'scope budget builder bounce decompose large change touched files
architectural seams'` returned no open or ended match on 2026-09-09. A broader search
for `decompose before build` found item-specific decompositions, but no general rule
that makes an oversized, already-bar-passing build bounce.

## Change

Add a scope-budget rule to the spec bar and the builder/reviewer briefs.

Before the first edit, the builder writes a terse scope inventory from the spec:
independently landable contracts, top-level subsystems, expected changed files, and
the tests that prove each contract. The builder bounces for decomposition when ANY
of these holds:

1. more than two contracts can land and be reviewed independently;
2. more than three top-level subsystems must change; or
3. the honest estimate exceeds twelve changed files, excluding generated output.

An item may exceed a numeric limit only when its spec explicitly names the atomic
invariant that makes intermediate landings invalid and carries measured evidence for
that claim. A broad outcome, shared release timing, or the convenience of one PR is
not an atomic invariant.

Mirror the rule in the review brief: a diff over budget without the explicit atomic
invariant is request-changes and decomposition, even when its tests pass. The bounce
report returns the inventory and proposed child boundaries to the orchestrator; it
does not widen or partially implement the item.

Update the relevant doctrine/brief tests with one under-budget fixture, one refusal
for each trigger, and one accepted atomic exception. Keep the thresholds in one
shared definition so the bar, builder brief, and review brief cannot drift.

## Non-goals

No limit on generated files, mechanical one-line migrations once their owning
contract is isolated, or the number of tests a small implementation may run. No
automatic decomposition algorithm. No permission for a builder agent to mutate the
board; the orchestrator still files and ranks the children.

## Access

`cosmic-lua/work`, read and write on a branch; no other repository.

## Ready when

`gitboard help bar`, a generated builder brief, and a generated review brief state
the same scope budget and atomic-exception rule; the fixtures prove all three bounce
triggers and the exception; and a spec shaped like `3J6saJCI` is refused or explicitly
marked for decomposition before a builder is instructed to edit product files.
