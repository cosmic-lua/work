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
