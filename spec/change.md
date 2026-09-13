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
