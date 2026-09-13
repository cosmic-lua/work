The Goal above cites 22 userdata-boundary sites across 7 files; the
tree today actually carries 23, across 8 files —
`awk -F'\t' '$3=="userdata boundary" {print $1}' docs/design/cast-sites.tsv
| sort | uniq -c` gives `cosmic/embed/init.tl 1, cosmic/fs/dir_test.tl
1, cosmic/fs/find.tl 3, cosmic/fs/ops.tl 2, cosmic/fs/tree.tl 1,
cosmic/fs/types.tl 12, cosmic/fs/walk.tl 2, cosmic/zip.tl 1`. The site
the Goal's tally omits is `cosmic/fs/dir_test.tl:170`, a fabricated
userdata test double (`return raw as unix.Dir -- cast: test double for
userdata boundary`) built to exercise `Dir`'s EOPNOTSUPP clamp; this
item does not touch it.

This item closes only the 9 sites inside `cosmic/fs/types.tl`'s
`statfs_methods` table. Everything else the Goal describes stays open,
and is not a smaller version of the same fix — it is a different
change, deferred rather than attempted here:

- `cosmic/fs/find.tl` (3 sites), `cosmic/fs/walk.tl` (2),
  `cosmic/fs/tree.tl` (1) and `cosmic/embed/init.tl` (1) — 7 sites —
  each cast `unix.opendir()`'s raw return straight to a locally-declared
  alias of `types.DirHandle` (`WalkDirHandle` in find.tl and walk.tl,
  `TreeDirHandle` in tree.tl, `EmbedDirHandle` in embed/init.tl —
  confirmed by `grep -n DirHandle cosmic/fs/find.tl cosmic/fs/walk.tl
  cosmic/fs/tree.tl cosmic/embed/init.tl`). Unlike `Stat`/`Statfs`,
  there is no `wrap_dir` function in `cosmic/fs/types.tl` today for
  these to route through — collapsing these 7 into one wrap point means
  designing and adding that function, then re-threading 4 files'
  `unix.opendir` call sites through it, each gaining a new failure
  branch. That is a separate, materially larger, multi-file change,
  not a self-typing fix, and is not this item.
- `cosmic/fs/ops.tl`'s 2 sites (`info as any` feeding
  `types.wrap_statfs(raw: any)`) and `cosmic/zip.tl`'s 1 site (tagged
  `-- cast: from any` in its own source comment, not `userdata
  boundary`, despite the census filing it under that heading) are also
  left alone here.
- The 3 remaining casts in `cosmic/fs/types.tl` itself — lines 263,
  280 and 294 — are not deferred work; they are permanent wrap-point
  floor (3 of the census's 6) and are expected to stay after this item
  lands.

A follow-up item for the 11 non-floor sites left open (the 7-site
DirHandle collapse, ops.tl's 2, zip.tl's 1, and a classification call
on dir_test.tl's test double) is recommended but not created by this
refinement.
