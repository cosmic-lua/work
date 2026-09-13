1. Add `_work.cachequery.items(c: cache.Cache): {item.Item} | nil, string`
   (`_work/cachequery.tl`, 141 lines today, ample room): one query each
   against `items`, `edges` (grouped by `from_id`/`kind` into `beats`,
   `blocked_by` + `block_reason`, and `other_edges` for any other kind),
   `builders`, and `speccers` (both ordered by `seq`), assembled into the
   same `{item.Item}` shape `store.list` returns. No new view, table, or
   schema change — reads the existing `items`/`edges`/`builders`/`speccers`
   tables `_work.index`'s DDL already creates. The cache must be CURRENT
   for the read: go through `cache.open`'s digest check (one ref snapshot,
   the load it already does for `find`), and when the cache is stale or
   absent let `cache.open` rebuild it first, as it does today.
2. `gitshow.tl:190,194`: replace `store.load(s, id)` + `store.list(s)` with
   one `cache.open(s.root)` + `cachequery.items(c)`; look up `it` as
   `by_id[id]` (or scan the returned list) instead of a separate
   `store.load`. Close the cache handle once done with it.
3. `gitview.tl:221,343`: replace each `store.list(s)` with `cache.open(s.
   root)` + `cachequery.items(c)`. Every downstream call
   (`status_report`, `next_report`, `act.next_action`, `intake.*`,
   `health.*`, `flow.*`, `prio.*`) is untouched — they already take
   `{item.Item}`/`{Item}` as a plain parameter.
4. Add a differential test (in `_work/cachequery_test.tl` or a new
   `_work/cachequery_items_test.tl`) proving `cachequery.items` matches
   `store.list` field-for-field on a fixture board carrying every field
   this item's own script exercised (multiple `beats`/`blocked_by` edges
   with reasons, an `other_edges` kind, `builders`/`speccers` entries,
   `held`) — mirroring the proof in this item's own Evidence, but as a
   committed test rather than a throwaway script.
5. Re-measure `show`/`next` against `_perf/bench/verbs_bench.tl`; record
   before/after in this item's own findings.
