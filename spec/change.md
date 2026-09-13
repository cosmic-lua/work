Validate `how` is one of `SIG_BLOCK`/`SIG_UNBLOCK`/`SIG_SETMASK` before
calling `sigprocmask()`, raising `luaL_argerror` otherwise. Update
`definitions.lua:6561-6565` to drop `|nil` from `oldmask` and the
trailing error lines. Regenerate cosmic's `cosmo.d.tl` and simplify
`cosmic/signal.tl`'s `sigprocmask()` wrapper accordingly.
