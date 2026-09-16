Add a nonblocking direction advisory for the two phrase families below to
`new` and ordinary `show`. Keep it separate from spec.ready_gaps,
workflow_rules.readiness_issues and every admission check. Direction hints
must not change whether an otherwise valid item can be filed, claimed,
taken or published. Preserve show --raw exactly.

Use a pure helper over only the Change section. Ignore fenced code,
blockquotes, and single/double quoted examples when detecting phrases.
Match case-insensitively at word boundaries, permitting ordinary whitespace.
Quantifier candidates: "every spawned agent", "all callers", "all the
callers", "each template", "every template", "all templates".
Existence candidates: "already knows", "already records", "already recorded",
"the caller has it". Emit at most one hint per family.

Suppress these hints when the Change contains a recognizable direction
anchor, including one in a later paragraph: a source-like path, a backticked
identifier or qualified identifier, an unquoted qualified/underscore field
identifier, or an explicitly introduced named set/list. Define the limited
anchor forms in the helper and its tests; this is a conservative textual
hint, not semantic proof. Ignore anchors inside fenced or quoted examples.
Do not broaden detection to the words every/all/each alone. In particular,
"every changed line" must not be flagged.

Print the hints under a distinct direction-advisory label rather than bar:
or flagged:. Wording names the matched phrase and the lack of a RECOGNIZED
direction anchor, asks where the builder should look, and says the hint is
advisory. It must not assert that the scope actually is unbounded, that a
field does not exist, or that absence of a hint proves a spec complete.

Update help bar to ask for a set/source pointer when relying on a quantified
scope or an existing fact, while preserving direction-not-measurement:
builders enumerate and verify against the current tree. Explain the bounded
hint and its limits. No inventories, counts, pasted commands/output or line
citations are required at refinement time.

Test both warning families; anchors in the same and later paragraphs;
qualified fields, paths and explicit lists; harmless changed-line wording;
phrases only in Non-goals/fences/quotes/blockquotes; and per-family deduping.
Integration tests must prove warnings appear in new/show without blocking
filing or claim admission, and raw show remains unchanged. Preserve existing
syntax-only readiness and no-measurement doctrine regressions.
