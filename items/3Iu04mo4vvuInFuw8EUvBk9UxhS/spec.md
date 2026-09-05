## Evidence

`vmX5_zQH2` («gentype: carry a binding's success @overload into its Teal
declaration, closing the 4 unix-path casts») closes 3 of 4 named cast
sites; `cosmic/net/socket.tl:437` (`-- cast: function shape (timeval
overload)`, `unix.setsockopt`'s `SO_RCVTIMEO`/`SO_SNDTIMEO` shape) needs
a `tool/net/definitions.lua` annotation this repo does not yet have —
filed and refined as `keP3_sWNy` («cosmopolitan: unix.setsockopt's
SO_RCVTIMEO/SNDTIMEO timeval shape has no machine-readable @overload in
definitions.lua — socket.tl:437's cast can't close without it»), whose
`## Change` lands in `cosmic-lua/cosmopolitan`, not here.

This item is that item's `cosmic-lua/cosmic`-side consequence: once a
cosmos release exists carrying the annotation, bump `bin/cosmic.pin` to
it and close the cast the new `@overload` unblocks.

## The question

Not resolvable yet: `keP3_sWNy` is `todo`, so the annotation this item
needs is not in any released `cosmos.zip`. Once `keP3_sWNy` is `done`
AND a `cosmic-lua/cosmopolitan` release exists whose commit descends
from its merged PR, refining this item's `## Change` means: bump
`3p/cosmos/cosmos_pin.tl` to that release (version + sha256, this
repo's normal pin-bump shape), run `bin/cosmic --make fetch && bin/cosmic
--make ci`, and re-check whether `cosmic/net/socket.tl:437`'s cast
still deletes cleanly against the regenerated types (`vmX5_zQH2`'s
generator work may or may not have landed by then — re-run its
`_types/gentype_parse.tl`/`gentype_render.tl` machinery, or hand-close
the cast if it hasn't, whichever the tree looks like when this is
picked up).
