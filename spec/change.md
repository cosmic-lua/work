`tool/lua/test_definitions_coverage.lua`: add a check that every
`function unix.<name>(...)` (and the other annotated namespaces the
file already walks) whose block carries any `@return` line carries a
FIRST `@return` whose type is not solely `string?`/`unix.Errno?` — a
block whose only return lines are the failure tuple's slots 2 and 3
has lost its success slot and is reported by name. Add the case to the
file's self-check fixtures (#344 introduced `TYPE_FIXTURES`; add a
sibling table for return blocks, or extend the mechanism the file has
at pull time). Mutation shown: with the guard in place, the deletion
above fails naming `unix.localtime`; restored, green.
