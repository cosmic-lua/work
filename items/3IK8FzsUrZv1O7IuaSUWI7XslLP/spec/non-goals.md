- **Do not remove the `/zip` templates from `package.path`.** Two
  readers depend on them and neither goes through `require`:
  `cosmic/teal.tl:20` (`package.searchpath("tl", package.path)` — the
  prove-tl-exists-without-loading-it check) and
  `_cli/require_hints.tl:20` (scans `package.path` templates with
  `io.open`). The searcher short-circuits ahead of them; introspection
  stays truthful.
- **Do not change resolution ORDER anywhere else.** The manifest tree
  searcher keeps seat 2 when installed (`cosmic/searcher.tl:361`), the
  cosmic `.tl` searcher stays last (`cosmic/searcher.tl:135`, pinned by
  `cosmic/tl_loader_test.tl`). Do not change
  `cosmic/tl_loader_test.tl`'s assertions; its index-2 probe returns a
  `.lua` path either way, so it passes unchanged — updating its comment
  wording is the only edit allowed there.
- **Do not touch `readable()` (`cosmic/searcher.tl:249`) or
  `tree_searcher`.** The in-project variant double-opens every tree hit
  through `io.open` + `load_built`; that is a separate mechanical
  follow-up, deliberately left here so this diff stays one hypothesis.
- **No new flags, no env knobs, no `cosmo.*` C-boundary change.** The
  `cosmo.*` contracts are frozen (AGENTS.md).
- Do not rename, delete, or weaken any `_perf` scenario or its
  `check()`; do not commit `o/perf/*.json`.
- Do not widen the diff to the `--modules`/manifest path, the strip
  floor, or `_make`.
