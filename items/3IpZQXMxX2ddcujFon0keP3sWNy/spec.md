## Evidence

Re-measured 2026-09-05 against `cosmic-lua/cosmopolitan@65bc139f`
(`tool/net/definitions.lua`'s own last-touching commit):

    git log -1 --format='%H %ci' -- tool/net/definitions.lua
    65bc139fc109e2bb8907889d020590f8512a7aa5 2026-09-04 03:04:00 +0000

`unix.setsockopt`'s current annotation, unchanged since the parent item's
evidence:

    sed -n '6487,6496p' tool/net/definitions.lua
    ---@param fd integer
    ---@param level integer
    ---@param optname integer
    ---@param value boolean|integer
    ---@return true|nil
    ---@return string? error
    ---@return unix.Errno? errno
    ---@overload fun(fd:integer, unix.SOL_SOCKET: integer, unix.SO_LINGER: integer, secs:integer, enabled:boolean): true|nil, string?, unix.Errno?
    ---@overload fun(serverfd:integer, unix.SOL_TCP: integer, unix.TCP_SAVE_SYN: integer, enabled:integer): true|nil, string?, unix.Errno?
    function unix.setsockopt(fd, level, optname, value) end

Two real overload arms (SO_LINGER, TCP_SAVE_SYN); the SO_RCVTIMEO/
SO_SNDTIMEO `(secs, nanos)` shape the C binding also accepts
(`third_party/lua/cosmo/lunix.c:2069` `IsSockoptTimeval`, branch at
:2088-2093) is documented only in the prose above the annotation block
(`sed -n '6334,6335p'` / `:6448,6449p'` both show
`--- unix.setsockopt(fd:int, level:int, optname:int, secs:int[, nanos:int])`),
never as a machine-readable `@overload`. `nanos` is optional at the C
level — `tv.tv_usec = luaL_optinteger(L, 5, 0) / 1000` — so the missing
overload's 5th param must carry `?`.

The two missing arms parse cleanly under this repo's own annotation
grammar. Verified by copying check 9's parser verbatim (lines 565-783
of `tool/lua/test_definitions_coverage.lua` at the commit above — the
pure-Lua type-expression parser + its self-check fixture table, no
change) into a standalone probe run under `cosmic-lua/cosmic`'s
bundled Lua (this repo has no system `lua`):

    ./bin/cosmic check_overload.lua
    OK    fun(fd:integer, unix.SOL_SOCKET: integer, unix.SO_RCVTIMEO: integer, secs:integer, nanos?:integer): true|nil, string?, unix.Errno?
    OK    fun(fd:integer, unix.SOL_SOCKET: integer, unix.SO_SNDTIMEO: integer, secs:integer, nanos?:integer): true|nil, string?, unix.Errno?
    clear   ---@overload fun(fd:integer, unix.SOL_SOCKET: integer, unix.SO_RCVTIMEO: integer, secs:integer, nanos?:integer): true|nil, string?, unix.Errno?
    clear   ---@overload fun(fd:integer, unix.SOL_SOCKET: integer, unix.SO_SNDTIMEO: integer, secs:integer, nanos?:integer): true|nil, string?, unix.Errno?

("OK" = check 9's `type_ok` accepts the region; "clear" = check 8's
banned `@overload fun(...): nil` fallibility-idiom pattern does not
match either line — both start with `true`, not `nil`). The probe's 24
copied self-check fixture assertions (the parser's own correctness
proof) all passed with no error, confirming the copy is faithful. This
is the type-GRAMMAR half of the ratchet only; it does not exercise the
C binding registry that check 9's surrounding coverage/conformance
tests compare against (that needs a built `lua` — `make -j$(nproc)
o//tool/lua/test` — which is this repo's actual PR gate, not run here).

## Change

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

## Non-goals

Not landing the `cosmic-lua/cosmic` side of this: bumping
`bin/cosmic.pin` to a release carrying this annotation, and closing
`cosmic/net/socket.tl:437`'s `-- cast: function shape (timeval
overload)` once it does. That needs a cosmos release built from a
commit at or after this change, which does not exist yet — it is
filed as its own item, `blocked_by` this one, so it is never offered
until a release carries the fix.

Not touching `unix.bind`/`unix.connect`/`cosmic/net/connect.tl:95` or
`vmX5_zQH2`'s generator work (`_types/gentype_parse.tl`/
`gentype_render.tl`) — unaffected by this annotation-only change.
`vmX5_zQH2`'s own spec still assumes all 4 named cast sites close in
one PR; re-scoping it (down to the 3 that don't need this item) is
that item's own refinement, not this one's.

Not touching the `SO_LINGER`/`TCP_SAVE_SYN` arms, the prose signature
diagrams above the annotation block, or `unix.getsockopt` (which has
no `@overload` tags at all and is a separate, harder gap — its return
shape varies by option instead of its argument shape).
