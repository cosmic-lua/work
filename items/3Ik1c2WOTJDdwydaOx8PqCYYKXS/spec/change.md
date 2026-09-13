Update `tool/net/definitions.lua`'s `unix.readlink` doc comment and
`@param` annotation to describe the real second parameter (an optional
buffer size, clamped to `[1, 0x7ffff000]`, defaulting to `AT_FDCWD`
resolution semantics as implemented) instead of the stale "dirfd"
claim inherited from upstream.
