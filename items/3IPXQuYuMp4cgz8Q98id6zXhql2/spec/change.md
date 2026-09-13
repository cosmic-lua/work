**This item is a container, not a slice.** 109 sites across ~50 library
files is far past one session's diff, and the sites do not share a fix:
each one is a judgment between two mechanisms the census names.

Decompose it by TREE, so the children are file-disjoint and can run in
parallel. The census's per-file counts give the cut; the heaviest, from
`docs/design/nil-flow.md`:

- `cosmic/fs/**` — `tree.tl` 10, `find.tl` 8, `walk.tl` 7, `path.tl` 6
- `cosmic/**` outside `fs/` — `time.tl` 7 (already its own item)
- `_eval/**` — `checks/json-cli.tl` 8 and siblings
- `_tool/**`, `_make/**`, `_docs/**`, `_perf/**`, `_cli/**`, `_build/**`

Each child slice states its own site list (re-derived, not copied — the
census is dated `e7ac1580`) and closes each site by ONE of:

- **A guard at the site** — the value really can be nil and the code has
  no answer. `if not x then return nil, "..." end`, or the module's own
  error shape.
- **A narrower signature at the producer** — the producer cannot fail in
  the way its type admits, so no caller should pay. This is the better
  fix wherever it applies, and the one that shrinks the census faster
  than the site count suggests.

The split between the two is the judgment no command makes, and it is
why this is not a mechanical sweep.
