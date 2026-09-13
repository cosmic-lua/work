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
