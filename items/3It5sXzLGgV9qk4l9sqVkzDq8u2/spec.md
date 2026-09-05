## Evidence

Parent item 3Isoczw9JmeVhX6X6NvBZCtZ5l7's research (see its `## Findings`)
found: `gitshow` calls `flow.binds/by_id/is_blocked/is_doing/role/substate`
and `prio.key_of/order_of/positions`; `gitview` calls
`flow.DOING_LIMIT/STAGE_REVIEW/by_id/doing_refusal/graph_problems/in_state/
is_blocked/stage_rank/substate/untriaged` and `prio.positions`. Every one of
these is classified `same` in the parent's coverage table except `by_id`
(superseded by the cache handle) and the ORDER half of `in_state`/`stage_rank`/
`unified`-shaped reads, which needs the lift+tie-break decision below.

`_work.index_priority.ensure_views` (creates `has_edge`/`own`/`ancestors`/
`band`/`unplaced`) is called nowhere outside its own test
(`grep -rn "ensure_views" _work cmd` — only `index_priority.tl` and
`index_priority_test.tl`). `_work/cache.tl`'s `rebuild` and
`_work/cachedb.tl`'s `expected_schema_fingerprint` run `index.DDL` and
`cachedb.EXTRA_DDL` but never `index_priority.EXTRA_DDL`, so `o/board.db`
today carries none of the priority views.

`cosmic.sqlite`'s `Database` record has no `create_function` (grep of
`/home/user/cosmic/cosmic/sqlite/init.tl` and a runtime probe both confirm
it: `type(db.create_function)` is `nil`, calling it raises "attempt to call
a nil value"). The production board (930 items, 244 `blocked_by` edges)
shows `priority.sorted`'s unseeded order diverging from
`index_priority.order_ids` starting at rank 10 of 930, because blocker lift
(`priority.lift`) is not modeled by any view.

## Change

1. Wire the priority views into the persistent cache: add
   `db:exec_script(index_priority.EXTRA_DDL)` to `_work/cache.tl`'s
   `rebuild` (right after `cachedb.EXTRA_DDL`) and to
   `_work/cachedb.tl`'s `expected_schema_fingerprint` (same spot).
   `schema_fingerprint` is derived from `sqlite_master`, so this alone
   forces every stale `o/board.db` to rebuild — no `SCHEMA_VERSION` bump
   needed.
2. Create `_work/cacheread.tl`: one function per `flow`/`priority` export
   classified `same` in the parent's coverage table (`is_doing`, `substate`,
   `has_open_children`, `role`, `in_state` membership, `doing_refusal`,
   `is_blocked`, `binds`, `root_of`, `item_problems`, `graph_problems`,
   `roots` placement/live/held, `untriaged`, `dominated`, `beaten_set`,
   `has_out_edge`, `positions`'s `placed`/`band`/`own`, `key_of`,
   `is_placed`, `cycle_problems`) — same name, same return record, taking
   an already-open cache handle (`_work.cache.Cache`) instead of `{Item}`.
   Add a lift-and-order helper that reads `own`/`band` from the views,
   queries `SELECT id FROM open_items` and `SELECT from_id, to_id FROM
   edges WHERE kind='blocked_by'`, and runs `priority.lift`'s existing
   walk (adapted to these thin rows) plus the unchanged `fnv32` tie-break
   in Teal — this backs `unified`, `in_state`'s full order, `stage_rank`,
   and `roots`'s order, so their PRINTED output is byte-identical to
   today's.
3. Migrate `gitshow` and `gitview`: swap `require("_work.flow")`/
   `require("_work.priority")` for `require("_work.cacheread")`, and each
   call site's `{Item}`/`items` argument for the already-open cache handle
   the verb obtains via `_work.cache.open`. `by_id` call sites are deleted
   (superseded); nothing else about either file changes.
4. Add differential assertions to `_work/index_test.tl`/
   `_work/index_priority_test.tl` (or a new `_work/cacheread_test.tl`)
   proving every migrated `cacheread` function agrees with its `flow`/
   `priority` counterpart, mirroring `index_priority_test.tl`'s existing
   pattern (fixture boards plus one random 300-item board) — extended with
   a board carrying `blocked_by` edges, since none of today's fixtures do.
5. Re-measure `show`/`next` against the production-board perf scenario
   (`_perf/bench/verbs_bench.tl`); record the before/after in this item's
   own findings.

## Non-goals

Changing any view's definition or the STRICT schema (the two new
`db:exec_script` calls run EXISTING DDL, unchanged); changing `gitshow`'s
or `gitview`'s printed output — every migrated function must match its
Teal counterpart exactly on the production board, order included; touching
`gitready`, `intake`, `action`, `gitgate`, `gitverdict`, `gitverbs`,
`gitgraph`, `gitcompare`, `gitfsck`, or `health` (their own follow-ups);
deleting `flow.tl`/`priority.tl` (item (e), blocked on this one and its
siblings).
