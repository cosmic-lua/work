Decide and document (as a decision record if it settles a real
tradeoff — e.g. what growth threshold or cadence counts as
report-driven versus noise) a concrete, mechanical step that turns
the size report's numbers into filed G9 work, for example: after each
release (or on some cadence), a session reads that release's
`size-compare.txt` (once the sibling item extending format_compare
with a doctrine-size line lands, including the doctrine delta)
against the prior release(s), and any per-tree growth outside normal
PR-by-PR noise (a threshold to be decided, not a taste call) gets
filed as a G9 item citing the exact numbers from the report as its
evidence. Land this as a documented step in `skills/work/decompose.md`
(or wherever the release/board cadence is otherwise documented), and
demonstrate it once by actually reading the current `size.json` trend
and filing (or explicitly declining to file, with reasoning) at least
one real pruning candidate from it — so the practice is proven, not
just written down.
