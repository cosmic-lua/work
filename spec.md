## Evidence

Found 2026-09-06 building board item `gVi7_9Ne8`
(`cosmic/net/init.tl: socket_pair doesn't narrow unix.socketpair's
integer|string fd2 slot`). That item's premise is that
`unix.socketpair`'s declared return shape is `fd1: integer, fd2:
integer | string, err: string?` (per cosmic-lua/cosmopolitan #385/#386),
and its `## Change` asks for an `is`-narrowing branch on `fd2` mirroring
`cosmic/tty.tl`'s `openpty` pattern.

That shape is not what this tree's pinned cosmos release generates.
`3p/cosmos/cosmos_pin.tl` here is `2026.09.04-65bc139fc`; the generated
`o/_types/types_gen/cosmo/unix.d.tl` from that pin declares:

```
socketpair: function(family?: integer, type?: integer, protocol?: integer): integer | nil, integer, string, Errno
```

`fd2` is a bare `integer`. Writing the spec's literal `if fd2 is string
then ... end` against this fails to type-check:

```
$ ./o/bin/cosmic --check types cosmic/net/init.tl
cosmic/net/init.tl:75:10: warning: fd2 (of type integer) can never be a string
cosmic/net/init.tl:75:3: error: cannot resolve a type for fd2 here
cosmic/net/init.tl:75:10: error: fd2 (of type integer) can never be a string
```

Confirmed the corrected `integer|string` shape exists in the sibling
`cosmic-lua/cosmopolitan` checkout's `tool/net/definitions.lua`
(`---@return integer|string fd2 the second half of the pair on
success, or the error string when the call failed`), but no release
carrying it is pinned in this repo yet — the pin `gVi7_9Ne8`'s own
Evidence measured against (`2026.09.06-bee599a73`, from a DIFFERENT
item's unrelated pin-bump experiment) was never landed here. Also
confirmed the OLD annotation is itself factually wrong at runtime (a
scratch script showed slot 2 holds the error string and slot 3 the
numeric errno on failure, not the 4-slot shape `unix.d.tl` currently
declares) — this is not a narrow reading gap, the pinned annotation is
stale in two ways at once.

## Change

Bump `3p/cosmos/cosmos_pin.tl` to a cosmos release descending from
cosmopolitan #385/#386 (verify the exact release tag and sha256 against
the cosmos release list; the evidence above names
`2026.09.06-bee599a73` as A release that carries it, from unrelated
work — confirm it's still current or find the latest one that is),
then `bin/cosmic --make fetch && bin/cosmic --make ci` to confirm the
bump alone doesn't regress anything else the newer pin's generated
types touch.

Once landed, `gVi7_9Ne8` unblocks: resume it (it already has a
correctly-scoped `## Change`) rather than respeccing its narrowing
logic — only the missing pin was in its way.

## Non-goals

Not `gVi7_9Ne8`'s own `fd2`-narrowing diff — that stays scoped to
`cosmic/net/init.tl` and resumes once this pin bump lands. Not a
general audit of every other binding this pin bump might also touch —
`bin/cosmic --make ci` after the bump is the mechanical check for
regressions; anything it doesn't catch is a separate finding.
