cosmic-lua/work's `docs/design/schema.md` is the design record D47 and D48
cite, and it still describes the four path parsers, `change_paths`,
`spec.revision` and step 5 of its plan as future work. Every step has landed:
the tree and fields (#154), the verbs (#157-ish chain), the migration (#163,
run in batches per cosmic's D49, #164), the pin (cosmic#1852), the retire's
dead-code half (#165) and its `key` half («8xtb_kfFu»). Add a short
"landed" section at the top naming each step's PR and what deviated from the
plan (the batched push and why, the split of the retire into two items, the
whole-board owner set), and mark the plan's step list as history rather than
rewriting it — the record is the value.
