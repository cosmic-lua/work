## Question

`«t55j_TZ4G»`'s `## Change` and `## Evidence` direct the builder to reuse a
bounded ancestor walk in `_work/flow.tl` (`reaches_board`, `outcome_of`,
lines 283-295/303-315) via `index[cur.parent]`. None of this exists in the
current tree.

## Evidence

Builder `build-t55j_TZ4G-6141b568` measured, 2026-09-07, against the item's
own worktree (branch `3IvYb8IW`, off `origin/main`):

- `_work/flow.tl` is 106 lines total: only `DOING_LIMIT`, the `STAGE_*`
  constants, and `substate_of_stage`. No `reaches_board`, no `outcome_of`,
  no ancestor walk of any kind.
- `reaches_board` exists, but in `_work/read.tl:219` — a single SQL query
  (`SELECT 1 FROM rank_path WHERE id = ?`) against a maintained table, not
  a Lua loop over `index[cur.parent]`.
- `outcome_of` does not exist as a function anywhere in the tree; the only
  hit is a stale doc-comment reference in `_work/readddl.tl:117`.
- `Index` (`_work/index.tl`) is now a SQLite connection
  (`record Index { db: sqlite.Database, ... }`), not a Lua table keyed by
  id — `index[cur.parent]` is not an expression the current `Index` type
  supports.
- `git log -S` traces the shift: `outcome_of` was introduced in #40
  (`bc8a0ae6`) and removed in #42 (`99e8a5a3`, "read: the board database is
  every verb's read model"), which moved ancestor/rank derivation from
  in-memory Lua walks into SQL views/recursive CTEs (`rank_path_view`,
  `rank_path` table, `outcome_descendants` view in `_work/readddl.tl` and
  `_work/index_rank.tl`).

## What needs deciding

The underlying goal — print the full ancestor chain (handle + title, one
line per level, nearest first) on `show ID` — still looks sound. It needs a
respec naming the actual current mechanism to build on: most naturally a
recursive CTE over `items` mirroring `broken_chains`'s
`WITH RECURSIVE chain(...)` in `_work/index.tl:206-219`, or a small Lua
loop calling `read`/`store` per hop, plus a way to fetch each ancestor's
title (e.g. via `store.load`). Whoever refines this should re-run the
spec's own cited evidence (grep for `reaches_board`/`outcome_of`, open
`_work/flow.tl` at the cited lines) before handing it off again.

## Status of the rest of the item

No edits were made; the builder stopped before touching any file. The
worktree at `/home/user/wt/3IvYb8IW` (branch `3IvYb8IW`) has no commits
beyond the branch point.
