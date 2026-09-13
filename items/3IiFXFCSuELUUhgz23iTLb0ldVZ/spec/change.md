Do **not** simply remove `|nil` from these two bindings' declared type
— that would encode "always succeeds," which the probe above proves
false for the case that matters. Instead fix `LuaUnixSetid`'s failure
detection for these two calls: read back the resulting fsuid/fsgid (no
direct `getfsuid(2)` exists; the established idiom is calling
`setfsuid(-1)`/`setfsgid(-1)` immediately after, which changes nothing
and returns the current value) and treat "requested id was not applied"
as failure, routing it through `LuaUnixSysretErrno` with a synthesized
`EPERM` so the Lua-level contract (`true|nil, err:string, errno?`) is
honestly satisfiable. Land the fix and a regression probe (the
transcript above, turned into an assertion) in the same commit as any
`definitions.lua` text change.
