## Evidence

Parent item 3Isoczw9JmeVhX6X6NvBZCtZ5l7's research found `gitshow.tl` and
`gitview.tl` are the ONLY two files, of the twelve `_work.flow`/`_work.
priority` importers, that call `store.list`/`store.load` directly
(`gitshow.tl:190,194`; `gitview.tl:221,343`) — every other importer
(`gitready`, `intake`, `action`, `gitgate`, `health`) receives its `{Item}`
list as a parameter from one of these two, and the remaining five
(`gitverdict`, `gitverbs`, `gitgraph`, `gitcompare`, `gitfsck`) load their
own fresh copy because they are mutations or a deliberately independent
audit (full inventory and reasoning in the parent's `## Findings`).

Measured against the production board (937 items): `store.list` costs
144.3 ms; hydrating an equivalent `{item.Item}` list straight from
`_work.cache`'s own SQL rows (`SELECT * FROM items` + `edges` +
`builders`/`speccers`, grouped in Lua — no git object fetch, no
`item.decode()` text parsing) costs 27.1 ms, a 5.3x speedup. Field-level
equivalence was verified, not assumed: every one of the 937 items' 15
scalar fields plus `beats`/`blocked_by`/`builders`/`speccers` (compared as
sorted sets) matched between `store.list`'s output and the cache hydration
— 0 mismatches.

Neither `cmd_show` (`gitshow.tl`) nor `cmd_status`/`cmd_next` (`gitview.tl`)
ever calls `gate.commit_and_publish` or otherwise writes through the
`store.Store` handle after loading — `store.list`'s lease side effect
(`s.leased_ref`/`leased_sha`/`leased_item`, used only by a SUBSEQUENT write
through the same handle) is unused by all three, so dropping it is safe.

Ready when: cosmic-lua/work#19 («M1Bw_JVNd», which edits `gitview.tl`) and
«GkFk_U7L5» (which adds a query beside `find` in `cachequery.tl`) are on
main — `git log --oneline origin/main | grep -c "3It2Kf7Z\|3It7RFOg"`
prints 2 — so this lands on top of both instead of colliding.

## Change

1. Add `_work.cachequery.items(c: cache.Cache): {item.Item} | nil, string`
   (`_work/cachequery.tl`, 135 lines today, ample room): one query each
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

## Non-goals

Changing any view's definition or the STRICT schema (no view is read by
this change at all); changing `gitshow`'s or `gitview`'s printed output —
every downstream function runs unchanged, so output is byte-identical by
construction, not merely by testing; touching `gitready.tl`, `intake.tl`,
`action.tl`, `gitgate.tl`, `gitverdict.tl`, `gitverbs.tl`, `gitgraph.tl`,
`gitcompare.tl`, `gitfsck.tl`, or `health.tl` (none need any change — see
the parent's `## Findings`); touching `flow.tl` or `priority.tl` (neither
needs any change, ever, under this design); building `_work/cacheread.tl`
or any per-function SQL port (the original, superseded design).
