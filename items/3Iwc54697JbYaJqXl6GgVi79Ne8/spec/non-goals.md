Not `Hkal_OAFy`'s own scope (the `zip.reader` cast) — this item is
purely the `cosmic/net/init.tl` narrowing gap that pin bump happened to
surface. Not re-litigating `unix.socketpair`'s own return shape on the
`cosmic-lua/cosmopolitan` side — that shape is accepted as given
(`#385`/`#386`); this item only fixes the `cosmic`-side consumer that
never adapted to it.
