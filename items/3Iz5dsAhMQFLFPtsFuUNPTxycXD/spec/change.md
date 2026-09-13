Reword the comment to state the INVARIANT directly instead of naming a
file: node's own `y`/`x` is the `as` token's position (set at parse
time, `tl.lua`'s `parse_expression`) — reporting here instead of at
`node.e1` (the operand) keeps this diagnostic's position consistent
with how a cast site is identified everywhere else in the tree: by its
exact `(file, line)`. Reporting at the operand instead would let this
diagnostic's line drift from whatever else keys a cast by position,
silently breaking any future join without this patch changing at all.
No functional change; a carried-patch comment edit only. No file name
(`_build/casts_test.tl`, `_cli/lint.tl`, or otherwise) appears in the
reworded comment — the invariant holds regardless of which module
currently keys casts by position.
