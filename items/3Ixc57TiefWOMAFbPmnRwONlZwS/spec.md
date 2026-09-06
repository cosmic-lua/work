## Evidence

Builder «eoMl_RZUo» (cosmic#1752, 2026-09-06) lost ~20 minutes to two
paths its spec named that do not exist in the tree: the built doc
index at `o/embed/cosmic/.docs/index.lua` (it lives at
`o/cmd/cosmic/embed_gen/embed/.docs/index.lua`) and a "paths gate" line
in `docs/contributing.md` (no such line). Builder «qPiX_DdxS» found its
spec's line numbers drifted ~75 lines. The spec bar's "measured, not
inferred" rule (`gitboard help bar`) covers counts and behaviour but
nothing mechanically checks that a path a Change names exists.
cosmic-lua/work#45 («AY6h_bM0B») adds `overlap.headroom_lines(body)`,
which already collects every path-shaped token in `## Change` and
`wc -l`s the present ones — an absent path is currently skipped
silently (its `paths_named` filters with `fs.is_present`).

Ready when: cosmic-lua/work#45 is merged (`git log --oneline -1 --
_work/overlap.tl` on main names it).

## Change

`_work/overlap.tl`: `headroom_lines` (or a sibling `absent_paths(body,
root)`) also returns, for every path-shaped token under a tree root the
caller passes, the ones that do not exist there: `absent: <path>` lines,
in the same list the `tight:` lines ride in. Paths under `o/` are
checked too (a spec that names a build output must name the one the
build makes). `gitboard show ID` prints them beside `tight:` — a
warning, never a `take` refusal — so a refiner sees a wrong path before
a builder pays for it. `_work/overlap_test.tl`: one present path, one
absent, one absent under `o/`; the absent ones are named, the present
one is not.

## Non-goals

No path resolution or guessing ("did you mean"). No change to the bar's
refusal set.
