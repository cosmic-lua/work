Rewrite `unix.tiocgwinsz`'s return annotation in
`tool/net/definitions.lua` to declare the real, shared-slot shape,
following the `unix.nanosleep` precedent
(`tool/net/definitions.lua:5876-5887`) exactly: a union type in the
slot that doubles, with prose stating the failure tuple explicitly.

Replace:

```
---@param fd integer
---@return integer|nil rows, integer cols cellular dimensions of pseudoteletypewriter display.
---@return string? error
---@return unix.Errno? errno
---@nodiscard
function unix.tiocgwinsz(fd) end
```

with:

```
---@param fd integer
---@return integer|nil rows
---@return integer|string cols cellular dimensions of pseudoteletypewriter
--- display on success, or the error string when the call failed —
--- failure returns exactly `nil, error, errno`, so the error lands in
--- this slot, not one of its own
---@return unix.Errno? errno the errno on failure; nil on success
---@nodiscard
function unix.tiocgwinsz(fd) end
```

No C code changes — `LuaUnixTiocgwinsz` already implements the fork's
standard `nil, error, errno` failure convention correctly; only the
doc comment overclaimed a shape the implementation never produces.
