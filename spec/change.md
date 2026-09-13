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
