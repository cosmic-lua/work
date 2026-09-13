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
