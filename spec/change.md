`tool/lua/test_definitions_coverage.lua`, check 9: refuse the three
shapes at depth 0 — `?` must follow `)` directly, a typed vararg's
colon must be flush (`...:`), and a depth-0 fun return list admits no
comma — with the comma rule SCOPED to the tags whose type token
gentype ends at whitespace (`@param`, `@return`, `@field`, `@type`); an
`@overload` line keeps its comma-separated return list, which gentype
reads whole. Add each bad shape and its good twin (`fun()?: integer`,
`fun(): ...: string`, `fun(): boolean`) to `TYPE_FIXTURES`, plus one
overload twin (`---@overload fun(): zip.Writer?, string?` accepted) so
the scope is pinned by a fixture. Gate green on the unmodified
`definitions.lua`.
