Two independent fixes are available; this capture's `Change` is the
first only — the second is named as a follow-up, not adopted here, to
keep this capture's risk to a documentation-only edit.

**1. (this capture) Fix the annotation to match actual behavior.**
Replace, in `tool/net/definitions.lua`:

```
--- Returns true if file descriptor is a teletypewriter. Otherwise nil
--- with an Errno object holding one of the following values:
---
--- - `ENOTTY` if `fd` is valid but not a teletypewriter
--- - `EBADF` if `fd` isn't a valid file descriptor.
--- - `EPERM` if pledge() is used without `tty` in lenient mode
---
--- No other error numbers are possible.
---
---@param fd integer
---@return true|nil
---@return string? error
---@return unix.Errno? errno
---@nodiscard
function unix.isatty(fd) end
```

with:

```
--- Returns true if file descriptor is a teletypewriter, false
--- otherwise — including when `fd` is invalid (`EBADF`) or
--- pledge()-restricted (`EPERM`). The underlying libc isatty() never
--- signals failure through its return value (only through `errno`,
--- which this binding does not currently surface), so there is no nil
--- case: a bad fd and a valid non-terminal fd are indistinguishable
--- here.
---@param fd integer
---@return boolean
---@nodiscard
function unix.isatty(fd) end
```

No C code changes in this capture — `LuaUnixIsatty`'s actual behavior
(a single boolean, always) is unchanged; only the doc comment and
declared type are corrected to match it. This alone moves
`unix.isatty` from NIL to EXACT in the census.

**2. (named, not part of this capture) Behavioral fix, if wanted.**
`LuaUnixIsatty` could call `ioctl(fd, TIOCGWINSZ, &ws)` directly (as
`LuaUnixTiocgwinsz` already does) instead of going through libc
`isatty()`, and branch on `errno`: `ENOTTY` → `false`; `EBADF`/`EPERM`
→ `nil, error, errno` — which is what the CURRENT doc comment already
(incorrectly) claims happens. That would be a real behavior change at
the C boundary (and needs the matching `definitions.lua` update plus a
cosmic-side type regen and `cosmic/tty.tl` review, per this repo's
"binding contracts are frozen at the C boundary... landed as its own
change" convention) — left for the goal owner's `compare` to decide
whether it's worth a separate item.
