Raise (`luaL_argerror` for the per-argument-shape checks,
`luaL_error` for the size-limit checks) instead of returning
`nil, err` for all 11 branches above; update
`definitions.lua:1632-1634`'s `@return` to drop the `|nil`/`?nil`,
making `getopt.parse` return `getopt.Result` unconditionally (dropping
slot 2 entirely, since `getopt_long()` itself never fails — its
outcomes are `result.unknown`/`result.missing`). Update the binding
contract rule's precedent list if one is tracked.
