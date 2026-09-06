## Goal

Document that `require("tl")` under a built `o/bin/cosmic` (or any
cosmic binary) resolves to the binary's OWN embedded `/zip/tl.lua`,
not the tree's `o/3p/tl/tl.lua` — even when `o/3p/tl` is prepended to
`package.path`. A session probing `tl`'s checker behavior directly
(as two research/review sessions did this same day) hits this exactly
once, burns a failed run and an investigation, then works around it
with `dofile()` on the explicit path — a fact worth stating once
rather than rediscovering per session.

## Evidence

Surfaced independently by two fresh-context reviewers on 2026-09-06,
both probing `cosmic-lua/cosmic`'s pinned `tl` directly for board item
`HlZW_zWbs` (Semantic rename for Teal — does tl's checker expose
enough to build one):

First reviewer's report: *"`require("tl")` resolved to the binary's
own embedded `/zip/tl.lua` (a different, likely differently-pinned
copy) rather than the tree's `o/3p/tl/tl.lua`, despite prepending it to
`package.path`... Worked around with `dofile()` on the explicit path
instead. Nothing in AGENTS.md flags that `package.path` prepending
doesn't shadow the embedded zip module for `require`."*

Reproduce directly: from a cosmic checkout with `o/bin/cosmic` built,

```
$ o/bin/cosmic -e 'package.path = "o/3p/tl/?.lua;" .. package.path; print(require("tl")._VERSION or require("tl").VERSION)'
```

returns the binary's own bundled `tl` version/behavior, not
`o/3p/tl/tl.lua`'s, because the zip filesystem's module resolution for
`require("tl")` takes priority over `package.path` prepending (cosmic's
own `zipos`-backed searcher runs ahead of, or instead of, the ordinary
Lua path searcher for a name the zip already carries at its root).

## Change

Add a short note to `AGENTS.md` (or `cosmic --docs guide.gotchas`,
wherever `guide.checking`/`guide.gotchas`'s existing narrower-gotchas
convention lives) stating: to run the TREE's pinned `tl` (as opposed to
the binary's own embedded copy) from a script executed by
`o/bin/cosmic`, `dofile("o/3p/tl/tl.lua")` (or equivalent explicit
load), not `require("tl")` with a prepended `package.path` — the
embedded zip module wins that resolution. Cite the failure mode
directly (a `require` that silently returns the wrong `tl`, not an
error) so it's searchable.

## Non-goals

Not changing cosmic's module resolution order — this item only
documents existing, presumably intentional behavior (the zip's own
`tl.lua` needs to always win for the BUILT BINARY's own normal
operation; probing the tree's copy from a script is the unusual case).
