## Change

A warm `show` and `next` each spawn one `git cat-file --batch` to read
every open item's spec body from git — 269 blobs on the live board
today (`_work/gitview.tl`'s `read_specs` → `store.read_specs` →
`gitread.read_specs`) — solely so `act.passes_bar` can count what
passes the spec bar. The bodies are already in the cache: the `search`
FTS table's `spec` column is filled on every save and rebuild. Derive
the bar at write time instead of at read time: add `ready INTEGER` to
`items` (1 iff `spec.ready_gaps(body)` is empty), set by
`cachedb.patch_item` from the body the save wrote and by the cold
rebuild, and make `queue` carry it; `passes_bar` reads the column, the
board view's "pullable" count is `SELECT count(*)` over `queue WHERE
ready`, and `show`/`next` never call `read_specs`. `take`'s own gate
still reads the one body it needs. Measure first with the git-spawn
wrapper `_work/writepath_test.tl` uses: `show` 2 spawns → 1, and the
bench's `show`/`next` medians before/after in the PR; `cache_test.tl`'s
patch-equals-rebuild ratchet gains the column.
