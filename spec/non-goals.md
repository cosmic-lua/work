- No change to `store.touched_at`: claim staleness stays keyed on the item
  file, and widening it is a separate question about what counts as working an
  item.
- No change to `_work/gitgraph.tl`'s `cmd_new`: a sidecar written at birth has
  no base to compare against.
- No `--force`/`--why` bypass on `spec`. The escape hatch is re-reading the
  sidecar and passing it as the base, which is one command and leaves a
  truthful base.
- No new field on the item record and no edit to `_work/item.tl`: the trail is
  git's, and the sidecar's own commits are what `show` was missing.
- No change to the `gitboard-<verb>:` verdict-line format, to any other verb's
  flags, or to `_work/flowstat.tl`'s whole-branch `store.history(s)` call.
- No edit to `skills/work/SKILL.md`, `docs/goals.md` or anything else on
  `main` — that is a different branch and a different pull request. This diff
  is the `board` branch only.
- No rewrite of the item sidecars whose prose names the bare `spec` command.
