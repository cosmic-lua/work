Either (a) delete the `board` branch of `cosmic-lua/cosmic` outright (a
human call — this session did not do it, since a branch deletion on a
shared repo is exactly the kind of hard-to-reverse action that needs
explicit sign-off, not an orchestrator's own judgment) so `git show
origin/board:_work/gitgraph.tl`-style greps and old muscle-memory can no
longer resolve to it; or (b), if it must stay (e.g. for git-archaeology or
because something still reads it), add a one-line `README.md` at its root
stating plainly "SUPERSEDED — the gitboard tool's live source and state
are `cosmic-lua/work`; this branch is kept only for history" so the very
first thing a session or human lands on when it clones this branch
self-corrects instead of building against it. Whichever is chosen,
`_work/gitowner.tl` (or wherever `gitboard new`'s repo-acceptance list
lives): if `cosmic-lua/cosmic` remains an accepted `--repo` value at all,
its `board` base specifically should be refused with a message pointing
at `cosmic-lua/work` instead — mechanical prevention outranks a README a
session can still skip past.
