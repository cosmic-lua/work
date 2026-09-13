Make `LuaUnixRaise` validate `sig` is a supported signal number and
raise via `luaL_argerror` before calling `raise()`, mirroring
`LuaUnixGettime`'s already-settled clock-id validation
(`lunix.c:1655-1670`, PR #277 — "The only failure is a clock id this
platform cannot serve, which is a bad argument rather than an
environmental condition."). Update `definitions.lua:5027-5034`'s
`@return` to drop `|nil` from `rc` and drop the trailing `string?`/
`unix.Errno?` lines, matching `clock_gettime`'s post-#277 shape. On the
cosmic side, regenerate `cosmo.d.tl`, then simplify `cosmic/signal.tl`'s
`raise()` wrapper (and its test) to the infallible-effect shape.
