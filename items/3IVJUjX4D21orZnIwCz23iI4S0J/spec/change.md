One source file and one test file, on the `board` branch.

**1. `_work/gitverdict.tl` (249 lines) — the refusal reads the durable
record.** Line 145's own-build refusal compares `session == (it.claim
or "")` — the claim alone. Replace the predicate with
`flow.built_by(it, session)` (`_work/flow.tl`: claim now, or in
`builders` ever), adding the `_work.flow` require. The refusal message
becomes `REFUSED: %s is %s's own build — the claim or builders record
names them, and no session accepts its own work`. Update the preceding
doc comment (lines 139-144), which still says "the claim … is what is
checked": the durable half exists now, and this is the verb reading it.

**2. `_work/gitverdict_test.tl` (205 lines) —
`test_verdict_refuses_a_past_builder`.** An item in `check` whose
`claim` names a second builder and whose `builders` carries the first:
a verdict by the first builder is refused (exit 1, no verdict written),
a verdict by the second is refused, and a verdict by a third session
lands. Build the state through the verbs where the file's existing
fixtures allow, or by `store.save` of an item carrying both fields —
the predicate under test is field-driven either way.

Measured 2026-08-27 at board head: `wc -l _work/gitverdict.tl` 249,
`_work/gitverdict_test.tl` 205; `grep -n "session == (it.claim"
_work/gitverdict.tl` → line 145 and nowhere else.
