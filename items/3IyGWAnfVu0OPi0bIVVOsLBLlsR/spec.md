## Evidence

Two doc ratchets parse function signatures as strings:
`_build/doc_returns_test.tl` counts return slots from `f.signature`
text (`grep -n 'return_slots' _build/doc_returns_test.tl` → the
`exports.return_slots(f.signature)` call), and the doc extractor
`_tool/doc/init.tl` reads `local function` lines and `@param`/`@return`
tags by line pattern (`grep -c 'match(' _tool/doc/init.tl`). Today
(2026-09-06) the returns ratchet went red on PR 1763 only once
`cosmic.ast` became public — a string count against a signature the
AST already holds as `rets` on the function node. The same extractor
decides the public surface `_build/public_surface_baseline.tl` guards.

## Change

`_tool/doc/init.tl`: the extractor walks `cosmic.ast.parse`'s tree for
`local_function`/`record_function` nodes and reads the name, the
parameter list and the declared return types from the node (`args`,
`rets`), keeping the doc-comment text from the token stream's comments
attached to the function's first token; `_build/doc_returns_test.tl`
compares `#f.returns` against the node's `#rets` and drops
`return_slots`. `_tool/doc/init_test.tl`: a multi-line signature and a
`function(...)` returning `T | nil, string` both count two slots; a
signature split across lines that the string parser miscounted is the
regression case. The extracted index is byte-identical for the current
tree before and after (`diff` of `o/cmd/cosmic/embed_gen/embed/.docs/index.lua`),
which is the acceptance.

## Non-goals

No change to what the docs render; no change to the visibility rule.
