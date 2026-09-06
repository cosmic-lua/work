## Evidence

`tool/net/definitions.lua`'s `unix.fcntl` (line ~5678,
`cosmic-lua/cosmopolitan`) carries one exact `@overload` per `cmd`
(`F_GETFD`/`F_SETFD`/`F_GETFL`/`F_SETFL`/the lock family), each
individually well-shaped, but Teal has no overloads — `gentype`
erases the whole set to a union return, so a caller narrowing on a
runtime `cmd` value still gets `any` back. `cosmic/fd.tl:187` (
`cosmic-lua/cosmic`) casts the result: `return result as integer --
cast: from any`.

Re-verified 2026-09-06: `handle:fcntl(cmd: integer, value?: integer):
integer | nil, string` (`cosmic/fd.tl:179`) is `cosmic.fd`'s ONLY call
site for `unix.fcntl` — confirmed via `grep -rn 'unix.fcntl' cosmic/*.tl`
finding no other caller — and it is DELIBERATELY generic: it accepts
any runtime `cmd`, forwards to the raw binding, and returns `integer`
(the common "flags" shape) regardless of which cmd was actually
passed. `cosmic.fd` exports the cmd constants directly for callers to
pass (`cfd.F_GETFD`, `cfd.F_SETFD`, `cfd.F_GETFL`, `cfd.F_SETFL` —
`cosmic/fd.tl:328-331`) rather than exposing typed per-cmd methods.

This differs from `zip.open`'s shape (see `VHkK_aA5k`, its sibling in
this census): there, THREE existing per-mode consumers already existed
(`cosmic/zip.tl`'s "read"/"write"/"append" branches), so splitting the
binding into `zip.reader`/`zip.create`/`zip.append` had three obvious,
already-separate call sites to redirect to. Here there is exactly ONE
call site, and it is generic ON PURPOSE — a cosmopolitan-side split
(e.g. `unix.fcntl_getfl(fd): integer|nil,string,unix.Errno`,
`unix.fcntl_setfl(fd, flags): boolean,string,unix.Errno`, mirroring
each `@overload` arm) would have nowhere to plug into on the
`cosmic-lua/cosmic` side without `cosmic.fd` ALSO changing its own
public API shape.

## Open question — needs a `cosmic.fd` API decision before this is a Change

Two shapes close the cast, and they trade off differently:

1. **Add typed accessor methods, keep the generic escape hatch.**
   `handle:flags(): integer|nil,string` (F_GETFL) and
   `handle:set_flags(flags): boolean,string` (F_SETFL) as new, typed
   methods calling new cosmopolitan-side split bindings directly (no
   cast); `handle:fcntl(cmd, value)` stays as-is, generic, `any`-typed
   internally, for the F_GETFD/F_SETFD/lock-family cases nobody has
   asked to type yet. This closes the cast for the two commands
   `cosmic.fd`'s own test file (`fd_test.tl`) actually exercises today
   (`F_GETFD`/`F_SETFD` also appear there, so a fuller version could
   cover four) without removing the fallback for less common cmds.
2. **Split every cmd, deprecate the generic method entirely.** More
   thorough, more surface area, and a breaking change to `cosmic.fd`'s
   public API (`handle:fcntl` disappears or narrows) for a cast that
   costs nothing at runtime and is invisible to callers.

Neither is dictated by the evidence above — it is a genuine API-shape
tradeoff for `cosmic-lua/cosmic`'s own public surface, not something
`cosmic-lua/cosmopolitan`'s binding layer can decide unilaterally. This
item is deliberately left without a `## Change` until that call is
made; refining it into one is choosing between the two shapes above
(or another), not restating this evidence with headers.

## Non-goals

Not `zip.open`'s split — that is `VHkK_aA5k`'s scope, already
resolved. Not a `cosmic-lua/cosmopolitan`-side change of any kind until
`cosmic.fd`'s own shape is decided — a binding split with no consumer
shape to match is exactly the kind of unforced API surface this
project's own doctrine says not to add speculatively.
