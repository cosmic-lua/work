## Evidence

`gitboard new --parent P` files a child with `rank: unranked` unless `--after`/`--before` is given (`gitboard show DouF_FlP8` → `rank: unranked` for two children filed 2026-09-06T21:17 under outcome «ineK_wWK6», itself ranked 3 of 26). `next` offers only ranked items, so both sat invisible through 8 `next` calls of one pass while lower outcomes' children were pulled; `new`'s verdict line (`«DouF_FlP8» [..] enters todo`) said nothing about it. `gitboard help rank` documents the positioning verbs; `help new` does not say a child without `--after`/`--before` is unpositioned.

## Change

`gitboard new --parent P` with neither `--after` nor `--before` positions the child LAST among P's ranked children (the same motion as `rank ID --last`), and its verdict line reports the position (`enters todo, rank 3 of 3 under «P»`); an unranked child can no longer be produced by `new`. `help new` states it. Test in `_work/new_test.tl` (or the verb's test file): a child filed under a parent with two ranked children reads `rank: 3 of 3`; with `--before` the existing behaviour holds.

## Non-goals

No change to `rank`, no re-ranking of existing unranked items, no change to outcome (top-level) ranking.

## Access

cosmic-lua/work, read and write on a branch; no other repository.

## Ready when

`gitboard new --parent P "t"` prints a `rank N of N under «P»` position and `show` on the child prints no `unranked`.
