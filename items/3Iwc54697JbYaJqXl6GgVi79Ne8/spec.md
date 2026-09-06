## Goal

`cosmic/net/init.tl:72`'s `socket_pair` uses `unix.socketpair`'s second
return value (`fd2`) as a plain `integer` without narrowing it, but the
binding's declared type is `integer | string` (the second slot carries
the error string on failure, sharing a slot with the success value on
this binding — see `cosmic-lua/cosmopolitan#385`/`#386`, which retyped
it that way). Fix `cosmic/net/init.tl` to narrow `fd2` before using it,
the way every other `T | nil, string` fallible-return call site in this
codebase already narrows before use.

## Evidence

Found 2026-09-06 as a side effect while building board item `Hkal_OAFy`
(a `cosmic-lua/cosmic` cast-removal item, unrelated to sockets):
bumping `3p/cosmos/cosmos_pin.tl` to `2026.09.06-bee599a73` (needed for
a DIFFERENT reason, `Hkal_OAFy`'s own `zip.reader` binding) surfaced a
pre-existing type error once the newer pin's types were pulled in:

```
cosmic/net/init.tl:72:49: argument 1: got integer | string, expected integer
```

at the call `make_socket(fd2)` inside `socket_pair`, where
`local fd1, fd2 = unix.socketpair(...)` on the success path is used
without narrowing. This is unrelated to `zip`/`Hkal_OAFy`'s own scope —
confirmed by reverting only the `cosmic/zip.tl` edit and keeping just
the pin bump: the `cosmic/net/init.tl` error persists on its own,
independent of anything `Hkal_OAFy` touches.

`unix.socketpair`'s current declared shape (verify against the pin's
embedded `cosmo/unix.d.tl` once picked up) returns `fd1: integer,
fd2: integer | string, err: string?` or similar — read the actual
current annotation before writing the fix, since this item's own
Evidence was captured during an unrelated pin-bump experiment, not a
dedicated read of the binding's contract.

## Change

In `cosmic/net/init.tl`'s `socket_pair` (around line 72), narrow `fd2`
before passing it to `make_socket`: check its type/nilness per the
binding's actual declared success/failure shape (read
`cosmo/unix.d.tl`'s current `socketpair` annotation first — do not
assume the exact shape from this item's Evidence alone) and branch to
an error return on the failure case, the same pattern this file
already uses for its other `unix.*` fallible calls. Add or extend a
test in `cosmic/net/init_test.tl` covering the failure path (e.g. an
invalid domain/type argument that makes `unix.socketpair` fail) to
confirm the narrowed branch is real and reachable, not just a cast.

Gate with `bin/cosmic --make ci`.

## Non-goals

Not `Hkal_OAFy`'s own scope (the `zip.reader` cast) — this item is
purely the `cosmic/net/init.tl` narrowing gap that pin bump happened to
surface. Not re-litigating `unix.socketpair`'s own return shape on the
`cosmic-lua/cosmopolitan` side — that shape is accepted as given
(`#385`/`#386`); this item only fixes the `cosmic`-side consumer that
never adapted to it.
