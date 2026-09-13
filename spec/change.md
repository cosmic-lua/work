Lands in `cosmic-lua/cosmopolitan` (not `cosmic-lua/cosmic`) — a
`tool/net/definitions.lua` annotation, no C change: the binding's
runtime behavior is already exactly this; only its declared shape is
incomplete.

In `tool/net/definitions.lua`, between the existing `SO_LINGER` and
`TCP_SAVE_SYN` `@overload` lines (6494) and `TCP_SAVE_SYN`'s (6495) and
the `function unix.setsockopt(fd, level, optname, value) end` line
(6496), insert two new `@overload` lines — one per optname, matching
the file's existing one-arm-per-real-call-shape convention (SO_LINGER
and TCP_SAVE_SYN each get their own line rather than sharing a generic
one):

    ---@overload fun(fd:integer, unix.SOL_SOCKET: integer, unix.SO_RCVTIMEO: integer, secs:integer, nanos?:integer): true|nil, string?, unix.Errno?
    ---@overload fun(fd:integer, unix.SOL_SOCKET: integer, unix.SO_SNDTIMEO: integer, secs:integer, nanos?:integer): true|nil, string?, unix.Errno?

Gate before opening the PR: `make -j$(nproc) o//tool/lua/test` —
this repo's AGENTS.md correctness gate — must pass, exercising the
real coverage/conformance/probe suite this item's own grammar-only
probe did not reach (the two arms parsing under the copied grammar in
Evidence is necessary but not sufficient). No other file changes; the
SO_LINGER and TCP_SAVE_SYN arms are untouched.
