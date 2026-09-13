Zero `errno` before calling `readdir()` in `LuaUnixDirRead` and check
it after: on a `NULL` return, if `errno` is nonzero, push `nil,
strerror(errno), errno` (the standard `LuaUnixSysretErrno`-style
tuple, matching the archetype `T|nil, err string, errno?`); if `errno`
is still zero, push a bare `nil` for legitimate end-of-directory, as
today. Update `tool/net/definitions.lua`'s declared return to add the
error and errno slots on the failure branch (mirroring the shape
`unix.nanosleep`'s fix (#315) and `unix.wait`'s recorded deviation use),
keeping the four-value success shape unchanged. This is a C-boundary
contract change (per this repo's AGENTS.md: "a deliberate contract
change needs a matching `definitions.lua` update here and a type regen
+ wrapper fix on the cosmic side, landed as its own change, never
inside an optimization") — land it here first, then land the matching
`cosmic/fs/dir.tl` `wrap_dir.read` update (surfacing the new error
slot, or documenting why it is deliberately still swallowed) as a
follow-up on the cosmic side, never in the same commit.
