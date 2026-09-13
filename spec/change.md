Add a short note to `AGENTS.md` (or `cosmic --docs guide.gotchas`,
wherever `guide.checking`/`guide.gotchas`'s existing narrower-gotchas
convention lives) stating: to run the TREE's pinned `tl` (as opposed to
the binary's own embedded copy) from a script executed by
`o/bin/cosmic`, `dofile("o/3p/tl/tl.lua")` (or equivalent explicit
load), not `require("tl")` with a prepended `package.path` — the
embedded zip module wins that resolution. Cite the failure mode
directly (a `require` that silently returns the wrong `tl`, not an
error) so it's searchable.
