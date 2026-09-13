`_build/casts_baseline.tl` and `_build/public_surface_baseline.tl` must be
byte-identical before and after for an unchanged tree — this is a machinery
swap, not a reformat, and a diff on either floor in this PR is a bug.

No change to either gate's comparison direction (casts still fails both
ways; the surface is still an exact set), to their failure wording, or to
what they measure — the failure contract and the regen verb are #1225.

No change to `cosmic/literal.tl`; #1222 already landed the contract this
slice consumes.

Do not touch `cosmic/embed/floor.tl`. It is the STRIP floor — what a
stripped artifact keeps — an unrelated meaning of the word that happens to
share a name. There is no module-path collision (`_tool.floor` versus
`cosmic.embed.floor`) and no reason to rename either.

Nothing in `_tool/coverage/` moves in this slice, and `.cosmic-coverage`
does not change. #1224 owns the coverage floor and is file-disjoint from
this one.
