Rewrite `unix.openpty`'s return annotation in
`tool/net/definitions.lua` to declare the real, shared-slot shape,
following the `unix.nanosleep` precedent
(`tool/net/definitions.lua:5876-5887`) exactly: union types in the two
slots that double, with prose stating the failure tuple explicitly.

Replace:

```
---@return integer|nil mfd, integer sfd, string name
---@return string? error
---@return unix.Errno? errno
---@nodiscard
function unix.openpty() end
```

with:

```
---@return integer|nil mfd
---@return integer|string sfd the subordinate fd on success, or the
--- error string when the call failed — failure returns exactly
--- `nil, error, errno`, so the error lands in this slot, not one of
--- its own
---@return string|integer|nil name the subordinate's filesystem path on
--- success, or the errno on failure; nil is never actually returned
--- here but kept for symmetry with the other two slots
---@nodiscard
function unix.openpty() end
```

No C code changes — `LuaUnixOpenpty` already implements the fork's
standard `nil, error, errno` failure convention correctly; only the
doc comment overclaimed a shape the implementation never produces.
