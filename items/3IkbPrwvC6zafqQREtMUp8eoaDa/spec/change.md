`tool/lua/test_definitions_coverage.lua`, check 9's `parse_union`: at
depth 0, refuse whitespace before the bar as well as after it (strip
`^|` only, not `^%s*|`, when not `grouped`), mirroring `scan_token`'s
rule that any depth-0 whitespace ends the type. Add `integer |nil rows`
(bad) and `(integer |nil)` (good) to the `TYPE_FIXTURES` table #344
introduced. Gate green on the unmodified `definitions.lua`.
