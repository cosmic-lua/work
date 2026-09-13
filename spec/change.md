The `key` half of «yXSL_x14T»'s retire, split out because that item was filed
at roughly 600 lines across 46 files and said where to cut. Nothing on the
board has ever carried a `key` — `grep -c '^key: '` over every tip's `meta`
printed `0` before the format-5 migration and prints `0` after it (1425 refs) —
so no ref needs rewriting and it was deliberately left out of the cutover. Its
removal is a mechanism change, in this order:

one — `grep -c '^key: '` over all 1371 metas prints `0`, so no ref needs
rewriting for this and it was deliberately left out of the format-5 cutover.
Its removal is a mechanism change, in this order: `_work/lanes.tl:234`
(`return item.is_open(it) and (it.key or "") == lane`) compares
`it.title == ("lane repair: %s is red"):format(lane)` — the one title
`file_repair` writes at `_work/lanes.tl:244`
(`local title = ("lane repair: %s is red"):format(lane)`) — and `:249` drops
`key = lane`;
`_work/gitgate.tl:280` (`if (taking.key or "") ~= "" then`) exempts a lane
repair by parentage instead, `if (taking.parent or "") == flow.LANE_PARENT then`,
with `LANE_PARENT` moved from `_work/lanes.tl:34` into `_work/flow.tl` (which
`_work/gitgate.tl:16` already imports, and which imports only `_work.spec`, so
no cycle closes); `_work/action.tl:277`
(`reason = ("lane repair: %s"):format(i.key),`) names `i.title`;
`_work/readddl.tl:95` (`WHEN w.key <> '' THEN 5`) derives the repair stage from
`w.parent = '<LANE_PARENT>'`; `_work/readddl.tl:243`
(`SELECT 'duplicate_key' AS kind, o.id AS id,`) and its join at `:247` are
deleted with the `duplicate_key` kind, and `_work.read.structure`'s callers
lose one kind — `_work/gitready.tl:96`
(`if row.id == it.id and (row.kind == "dangling_parent" or row.kind == "deep_chain") then`)
already names only two kinds and needs no edit; `_work/indexddl.tl:89`
(`CREATE UNIQUE INDEX one_open_item_per_key`) and the `key` column at `:39`
go, with `key_duplicates` (`_work/index.tl:171`) and its call at `:247`;
`_work/index.tl:86`, `_work/cachequery.tl:186` and `:203`, `_work/read.tl:250`
and `:275`, `_work/gitfsck.tl:53`'s `ITEM_COLUMNS`, the `record Item` field
(`_work/item.tl:29`, `  key: string`, living in `_work/itemtype.tl` after
`02-tree-and-fields` moved the record there) with `_work/item.tl`'s
`SPEC`/`Raw`/`decode`/`encode` entries, and
`_work/itemtree.tl`'s `META_KEYS` entry and `put("key", ...)` all drop it.
`_work/cachedb.tl:62` (`local SCHEMA_VERSION < const > = 8`, at `9` after
`02-tree-and-fields`) goes to `10`.

The two halves overlap in exactly two files — `_work/itemtree.tl` (`META_KEYS`
and `put`) and `_work/gitfsck.tl` (`ITEM_COLUMNS`, which this half edits, plus
the two new reports the dead-code half adds) — and neither reads what the
other deletes, so either order lands. This half updates `_work/lanes_test.tl`,
`_work/gitgate_test.tl`, `_work/index_test.tl` and `_work/read_test.tl`, and
`README.md`'s `fsck` paragraph loses `two open items sharing a key`. Hand-edit
the `.cosmic-coverage` rows for `_work/item.tl` and `_work/itemtree.tl` rather
than running `--make coverage --baseline`.
