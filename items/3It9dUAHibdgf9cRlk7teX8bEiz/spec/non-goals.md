A full libgit2-style reimplementation (parsing packfiles, its own
object database) — this stays a thin, typed wrapper over shelling out to
`git`, exactly like the code it is ported from; migrating
`cosmic-lua/work`'s own `_work/refs.tl`/`gitobj.tl` onto the published
module — a separate, later item once this stabilizes, the same
sequencing «Bb5n_SBqt» used for `_fuzz`; changing any function's
contract from what the ported code already proves.
