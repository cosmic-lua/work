Changing any view's definition or the STRICT schema (no view is read by
this change at all); changing `gitshow`'s or `gitview`'s printed output —
every downstream function runs unchanged, so output is byte-identical by
construction, not merely by testing; touching `gitready.tl`, `intake.tl`,
`action.tl`, `gitgate.tl`, `gitverdict.tl`, `gitverbs.tl`, `gitgraph.tl`,
`gitcompare.tl`, `gitfsck.tl`, or `health.tl` (none need any change — see
the parent's `## Findings`); touching `flow.tl` or `priority.tl` (neither
needs any change, ever, under this design); building `_work/cacheread.tl`
or any per-function SQL port (the original, superseded design).
