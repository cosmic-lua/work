## Evidence

`cosmic/quicksand/caps.tl:63`'s `number_of(name)` casts `(unix as
{string: any})[name] as integer -- cast: dynamic constant lookup` to
resolve a Linux capability name (`CAP_NET_ADMIN`, etc.) to its number
— same class as `rhKJ_HSQd`'s E*/SIG* gap ("binding constant by name",
`docs/design/cast-sites.tsv:52` row for this site), found while
tracing that item's own registration mechanism.

`CAP_*` constants are registered the same way E*/SIG* are — individual
hand-written calls, not `LoadMagnums`:

    $ grep -c 'LuaSetIntField(L, "CAP_' third_party/lua/cosmo/lunix.c
    42

in `cosmic-lua/cosmopolitan`'s `third_party/lua/cosmo/lunix.c`. No
`kCapNames`-style `MagnumStr` table exists.

## Change

Not written — this is the same fix shape `rhKJ_HSQd` applies to E*/SIG*
(build a `MagnumStr` table from the 42 existing calls, register via
`LoadMagnums`, add a `unix.CAP: {string: integer}` map, close the cast
in `cosmic/quicksand/caps.tl`). Refining this item should read
`rhKJ_HSQd`'s finished Change as the worked template once that item
lands, rather than re-deriving the approach from scratch — the only
new work here is CAP_*'s own name list and confirming `caps.tl:63`'s
call site swaps the same way `errno.tl`'s does.

## Non-goals

Not `rhKJ_HSQd`'s own E*/SIG* scope. Not blocked on `rhKJ_HSQd`
technically (the two families are independent C-level changes), but
sequencing after it is strongly recommended: the pattern this item
needs is exactly what `rhKJ_HSQd`'s review will validate or correct.
