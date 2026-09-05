## Evidence

The board now has two readers for the same facts. `_work/flow.tl` (490 lines)
and `_work/priority.tl` (478 lines) compute states, substates, roots,
blocking, and the `beats` order by walking `{Item}` in Teal; `_work/index.tl`
and `_work/index_priority.tl` express the same facts as SQL views over the
STRICT index (`open_items`, `roots`, `containers`, `workable`, `state`,
`substate`, `dominates`, `has_edge`, `own`, `ancestors`, `band`, `unplaced` —
`grep -n "CREATE VIEW" _work/index.tl _work/index_priority.tl`), held equal to
the Teal readers by differential tests (`_work/index_test.tl` 323 lines,
`_work/index_priority_test.tl` 225 lines, 19 cases between them). Only the
Teal side is read by verbs: 13 non-test modules import `_work.flow` or
`_work.priority` (`grep -rln 'require("_work.flow")\|require("_work.priority")'
_work cmd | grep -v _test`: action, flow, gitcompare, gitfsck, gitgate,
gitgraph, gitready, gitshow, gitverbs, gitverdict, gitview, health, intake),
and the views are consulted by nothing but their tests and `find`. Every save
already patches the cache (`_work/cache.tl`), so the index is current
whenever a verb runs; the duplicate reader is pure cost — two definitions of
"pullable" to keep in step, and `flow.tl`/`priority.tl` both inside 30 lines
of the 500-line cap.

Profiled 2026-09-05 (module functions wrapped with timers around
`_work.gitboard.main("show")`, live board, 929 refs): `show` 233 ms total;
`store.list` 146 ms, inside it `gitread.list` 123 ms of which the four
`cat-file --batch` reads are 102 ms inclusive — the same reads from a shell
cost roughly 40 ms, so about 60 ms of every whole-board load is Lua parsing
and item decoding, not git; then `read_specs` 19 ms, `cache.open` 15 ms,
`touched_at` 15 ms. A read served from the current cache skips all of it:
`find`, which already does, is 29 ms end to end. That is the size of this
item's prize for `show`/`next`, and why speeding the parser is not filed
separately.

## Change

Research: decide how the verbs read the index instead of `flow.tl`/
`priority.tl`, and file the file-disjoint follow-ups that do it. Deliverable
is a `--result` handover carrying the findings below plus the filed items,
not code.

1. Coverage table. For each of the 17 functions `flow.tl` exports and the 10
   `priority.tl` exports (its trailing `M = {...}` table), record the view or
   query that yields the same answer, or `none`. Prove each `same` by running
   both over the production board (`_work.cache.open` gives the connection;
   `gitread.load` the items) and diffing the result sets, pasted as counts in
   the findings. Record each `none` with the reason (an iteration order, a
   refusal string, a seeded tie-break).
2. The order wall. `priority.sorted` breaks ties with `fnv32` (priority.tl:338)
   seeded per session, and every verb's output order is frozen by its tests
   and by `gitboard-next:` lines agents read. Measure whether `cosmic.sqlite`
   can register a scalar function (`grep -n "create_function\|register"
   cosmic/sqlite/*.tl` in a cosmic checkout matched nothing on 2026-09-04;
   check the pinned `cosmo.lsqlite3` declarations in
   `o/_types/types_gen/cosmo/lsqlite3.d.tl` too). If it cannot, the decision
   is: views deliver bands and dominance, the hash tie-break stays in Teal on
   top of the view's rows. Write the decision down either way.
3. The seam. Readers move into `_work/cachequery.tl` (135 lines today) or a
   sibling `_work/cacheread.tl` when it would cross 500: one function per
   `flow`/`priority` export, same name, same return record, taking the cache
   handle instead of `{Item}`. Callers change one `require` line and one
   argument; nothing else moves. Any verb that must work with no cache (a
   fresh clone before `sync`, `fsck` on a corrupt cache) is named in the
   findings with how it degrades — rebuild first, or keep the Teal path.
4. Follow-ups. File one item per importer cluster under this same parent with
   `--repo cosmic-lua/work`, file-disjoint from each other: (a) gitshow +
   gitview, (b) gitready + intake + action, (c) gitgate + gitverdict +
   gitverbs, (d) gitgraph + gitcompare + gitfsck + health, and last (e) delete
   `flow.tl`/`priority.tl` and fold their tests into the differential tests,
   `blocked_by` (a)–(d). Each carries the coverage rows it depends on.

## Non-goals

Changing any view's definition or the STRICT schema; changing any verb's
printed output; moving the lanes observation; the embedding stage (its own
item).

## Findings (research pass 2026-09-05, reworked after `request changes`)

**Re-run confirms the Evidence exactly**, with normal day-to-day drift:
12 `CREATE VIEW`s, the 13-importer grep, all five line counts, 19 test
cases — all unchanged (929 → 930 → 937 refs across three separate re-syncs
of the production board over two days; a moved number each time, never a
shape break). Timing re-run: `show` 236 ms, `store.list` 149.8 ms,
`gitread.list` 128.7 ms, `cat_file_batch` 107.3 ms, `read_specs` 16.8 ms,
`cache.open` 15.0 ms; `find` 30 ms end to end — all within a few ms of the
Evidence's numbers. `priority.tl`'s `M` table actually exports **11**
functions (the eleventh, `edge_refusal`, was undercounted when the spec was
written); `flow.tl`'s 17 is exact once `ready_gaps` (unrelated to graph/state
derivation) is excluded from the 18 function-shaped keys of its 25-key `M`
table (`DOING_LIMIT` + six `STAGE_*` constants make up the rest).

### 1. Coverage table

Kept as evidence that the SQL views ARE a faithful, provable stand-in for
`flow.tl`/`priority.tl`'s Lua derivations — the finding in section 5 below
changes how that fact gets exploited, not whether it holds.

**`_work/flow.tl` (17 functions)**

| function | same/none | view or query | evidence |
|---|---|---|---|
| `is_doing` | same | `state` view (`state = 'doing'`) | 0/201 mismatches (open items only) |
| `substate` | same | `substate` view (no `queued` arg) | 0/930 mismatches |
| `stage_rank` | none | no view composes `state`+`substate`+`key` into one rank yet | — |
| `unified` | none | needs `stage_rank` plus per-bucket ordering (see §2) | — |
| `by_id` | none (superseded) | a cache connection needs no per-call in-memory index | — |
| `has_open_children` | same | `containers` view | 0/930 mismatches |
| `role` | same | composed from `containers` + `roots` | 0/930 mismatches |
| `in_state` | same (membership) | `workable` ⋈ `state` | membership proven (3 doing = 3); order — see §2 |
| `doing_refusal` | same | `workable ⋈ state='doing'` count vs `DOING_LIMIT` | lua=3, sql=3 |
| `is_blocked` | same | `edges ⋈ open_items` (`kind='blocked_by'`) | 0/930 mismatches |
| `binds` | same | base case of the query above | structurally identical, not independently diffed |
| `waits_on` | none | no transitive `blocked_by` closure view; also a pre-write check — see §5 | — |
| `root_of` | same | `ancestors` ⋈ `roots` + self-check | 0/930 mismatches |
| `item_problems` | same | `dangling_parents` + `broken_chains`, already in `index.tl` | 0/0 on this board; nonzero already proven by fixtures |
| `graph_problems` | same, as a superset | `index.problems()` ⊇ | 0 extra lines today |
| `roots` | same (placement/live/held) | `roots` ⋈ `unplaced` ⋈ `ancestors` ⋈ `items.held` | 12 placed roots, lua=sql |
| `untriaged` | same | `roots` ∖ `containers` ∩ `unplaced`, id-ascending | exact set match, 2=2 |

`ready_gaps` re-exports `_work.spec.ready_gaps` — out of scope, unrelated to
the graph/state migration.

**`_work/priority.tl` (11 functions)**

| function | same/none | view or query | evidence |
|---|---|---|---|
| `index_of` | none (superseded) | same rationale as `by_id` | — |
| `dominated` | same | `dominates` view, filtered by winner | 0/50 sampled |
| `beaten_set` | same | distinct `beats` `to_id` query | lua=59, sql=59 |
| `has_out_edge` | same | `edges`/`items` query | 0/930 mismatches |
| `positions` | same (`placed`/`band`/`own`) | `own` + `band` + `unplaced` views | 0/930 mismatches on all three; the other four fields — see below |
| `key_of` | same | `index_priority.position_of` | proven via `positions` |
| `order_of` | none | see §2/§5 | — |
| `is_placed` | same | `unplaced` view | proven via `roots`/`untriaged` |
| `sorted` | none, full contract | see §2/§5 | first divergence at rank 10/930 |
| `cycle_problems` | same | `priority_cycles`/`cycle_ids` | 0=0 today; nonzero proven by fixtures |
| `edge_refusal` | same in principle | `dominates` existence check | its one caller needs it against an uncommitted edge — see §5 |

### 2. The order wall — corrected

**§2 was wrong about the mechanism behind the observed divergence.** Re-probing the
two ids that swap at rank 10 (`3Ip8zrCbHnPiV5bRM49XvoxXNCM`,
`3Ip8wKdwg5luRdQ0MHhfh4nDtCK`) directly:

```
3Ip8zrCbHnPiV5bRM49XvoxXNCM: placed=true band=8 own=1 lift_band=8 lift_own=1 lifted_from="" unblocks=4
3Ip8wKdwg5luRdQ0MHhfh4nDtCK: placed=true band=8 own=1 lift_band=8 lift_own=1 lifted_from="" unblocks=0
board-wide: 0/937 items have lifted_from ~= ""
```

Both ids carry `lift_band == band` and `lift_own == own` — **neither is
lifted**, and board-wide, **zero of 937 items have ever been lifted**
(`lifted_from` empty everywhere). Blocker-lift remains a real, unmodeled gap
in the SQL views, but it is not what fires today. The field that actually
differs is `unblocks` — 4 vs 0, the THIRD tie-break tier `priority.sorted`
reads after band and own (how many open items wait on this one through a
`blocked_by` chain). `index_priority.order_ids`'s `ORDER BY` has no
`unblocks` term at all — no view computes it — so on a band/own tie it falls
straight to id order, which is exactly where `3Ip8wKdw` (< `3Ip8zrCb`
lexically) and `3Ip8zrCb` (higher `unblocks`) swap.

Both gaps — the seeded tie-break (confirmed absent: `cosmic.sqlite`'s
`Database` has no `create_function`, confirmed by grep and by a runtime
probe raising "attempt to call a nil value") and this `unblocks` count both
need the SAME missing capability: a transitive `blocked_by` closure view,
analogous to `dominates` but over `blocked_by` instead of `beats`, which
does not exist today (only a direct, one-hop `edges` query does). Building
one is a real, if bounded, SQL design task — **and section 5 below found it
is unnecessary**, so the engineering decision this section originally
reached (views for band/own, Teal for the rest) is superseded, not merely
corrected, by a simpler alternative that needs neither the seeded tie-break
nor a new closure view at all.

### 3. The seam — original design (superseded by §5)

The original plan: `_work/cachequery.tl` stays at 135 lines; migrated
readers go into a new sibling `_work/cacheread.tl`, one function per
`flow`/`priority` export, same name, taking the cache handle instead of
`{Item}`.

A wiring gap this plan would have needed regardless: `_work.index_priority.
ensure_views` (the `has_edge`/`own`/`ancestors`/`band`/`unplaced` views) is
called nowhere outside its own test — `o/board.db` today does not carry
them. Under §5's revised design this gap no longer matters for THIS item
(the views are not consulted at all), so it is recorded here as a
pre-existing, orthogonal piece of dead wiring, not something this item's
follow-up needs to fix.

**Verbs that must keep the Teal path** (unchanged conclusion, now understood
as an instance of the general rule §5 states): `gitfsck` (deliberately
audits raw git truth, bypassing the cache by design); `gitcompare`'s
pre-write cycle check (validates a candidate edge the persistent cache does
not yet reflect); `gitgraph`'s `block`/`unblock` (`flow.waits_on` at
`gitgraph.tl:238`, same shape as `gitcompare`'s check).

### 4. Rigor pass: every `flow.`/`prio.` call site, every cluster

Requested after the two gaps above: `grep -n "flow\.\|prio\."` over every
file in every cluster, every call site classified, with `flow.Index`/
`prio.Position` type-alias references included
(`grep -rn "flow\.Index\|prio\.Index\|prio\.Position" _work cmd | grep -v _test`
— hits in `intake.tl`, `health.tl`, `action.tl`, plus `flow.tl`/`priority.tl`'s
own internal cross-references).

**Call-site count per file** (`grep -c "store\.list\|store\.load\b"`):

| file | store.list/load calls | shape |
|---|---|---|
| `gitshow.tl` | 2 (`:190` load, `:194` list) | pure read (`show`) |
| `gitview.tl` | 2 (`:221`, `:343`, both list) | pure read (`status`/`next`) |
| `gitready.tl` | 0 | pure function, `items`/`all` passed in |
| `intake.tl` | 0 | pure function, `items` passed in |
| `action.tl` | 0 | pure function, `items` passed in |
| `gitgate.tl` | 0 | pure function, `items` passed in |
| `health.tl` | 0 | pure function, `items` passed in |
| `gitverdict.tl` | 2 (mutation `verdict`) | mutation |
| `gitverbs.tl` | 6 (mutations `take`/`drop`/`done`/`sync`) | mutation |
| `gitgraph.tl` | 5 (mutations `new`/`attach`/`block`/`unblock`/`set`) | mutation |
| `gitcompare.tl` | 4 (mutations `compare`/`hold`/`unhold`) | mutation |
| `gitfsck.tl` | 3 (read-only, deliberately bypasses cache) | audit |

Tracing where the zero-`store.list` files get their `items`/`all` from:
`gitready.ready_problems` is called from `gitshow.tl:206` (read) AND
`gitverbs.tl:182` (mutation, via `gitgate.review_debt_refusal` at
`gitgate.tl` — itself only ever called from `gitverbs.tl:182`, a mutation).
`intake`/`action`/`health` are all reached, transitively, from
`gitview.tl`'s two `store.list` calls (`status_report`/`next_report` →
`act.next_action` → `intake`/`health`) — **`gitview.tl` and `gitshow.tl` are
the only two files in all twelve importers where `store.list`/`store.load`
is called directly**; every other file receives `{Item}` from one of those
two, or (for the five mutation files) loads its own fresh copy because it
is about to write.

**`gitgraph.tl`'s full inventory** (every line, as requested):

| line | call | classification |
|---|---|---|
| 77 | `flow.by_id(all)` (in `new`) | mutation-fed, `all` already loaded for the commit; superseded regardless (by_id is dead weight even in Teal) |
| 140 | `flow.by_id(all)` (in `attach`) | mutation-fed |
| 152 | `flow.root_of(parent_item, index)` (in `attach`, checks the prospective parent's OWN chain reaches a root) | reads committed state, but `all`/`index` are already in memory for the same commit — no `store.list` this eliminates |
| 185 | `flow.has_open_children(all, id)` (in `attach`, post-commit, decides wording only) | same — `all` already in memory, pre-dating the commit |
| 224 | `flow.by_id(all)` (in `block`/`unblock`) | mutation-fed |
| 238 | `flow.waits_on(index, blocker, id)` | validates the CANDIDATE blocker edge before it is written — cannot read the persistent cache at all |
| 288 | `prio.is_placed(prio.positions(all), blocker)` (in `block`/`unblock`, guidance text only) | same as 152/185 — `all` already in memory |

No line in `gitgraph.tl` calls `store.list` more than once per verb, and no
line's classification changes if it moves — see §5.

### 5. Revised recommendation: hydrate `{Item}` from the cache, don't reimplement the readers

The rigor pass above shows the original per-function SQL-reimplementation
design (§3) attacks the wrong layer. Every mutation-verb call (five of the
twelve files) is fed by a `store.list`/`store.load` that verb's own commit
lease already requires — migrating those calls to a cache-handle read adds
a SECOND read for zero savings, and for `gitcompare`/`gitgraph`'s cycle
checks specifically, cannot even be correct (the cache reflects only
committed state). `gitready`/`intake`/`action`/`gitgate`/`health` call
NEITHER `store.list` NOR the cache themselves — they are pure functions fed
by whichever of the two READ entry points, `gitshow.tl` and `gitview.tl`,
loaded the board. **Those two files are the entire migration surface.**

The measured alternative: rather than port 28 functions to SQL and manage
the seeded-tie-break/blocker-lift gap (§2), hydrate a `{Item}` list directly
from the cache's own rows — already-typed SQL columns, no git object fetch
and no `item.decode()` text parsing — and hand it to `flow.tl`/
`priority.tl`'s EXISTING, UNCHANGED functions.

```
store.list:       937 items, 144.3 ms
cache hydration:  937 items,  27.1 ms   (5.3x faster)
```

(`cache.open` → `SELECT * FROM items` + `SELECT ... FROM edges` +
`builders`/`speccers`, grouped into `{item.Item}` shapes in Lua.) Field-level
equivalence, not just a count: every one of 937 items' 15 scalar fields plus
`beats`/`blocked_by`/`builders`/`speccers` (as sorted sets) diffed between
`store.list`'s output and the cache hydration — **0 mismatches**.

This changes every downstream conclusion:

- **§2's order wall dissolves.** `priority.sorted`/`.positions` run
  UNCHANGED over the hydrated list — no seeded tie-break to reimplement, no
  blocker-lift or `unblocks` gap to close, because ordering never leaves
  Teal. The `unblocks`-vs-lift correction above stands as evidence for why
  the SQL-reimplementation path was riskier than this one, not as a live
  constraint on it.
- **§3's seam becomes ONE new function**, not a new module of ~28 ports:
  `_work/cachequery.tl` (135 lines, room to spare) gains
  `items(c: cache.Cache): {item.Item} | nil, string`, mirroring
  `store.list`'s shape exactly.
- **Only `gitshow.tl` and `gitview.tl` change.** Three call sites
  (`gitshow.tl:194`, `gitview.tl:221`, `gitview.tl:343`) swap `store.list(s)`
  for `cache.open(s.root)` + `cachequery.items(c)`; `gitshow.tl:190`'s
  separate `store.load(s, id)` becomes unnecessary (`it` is already in the
  hydrated `all`). Neither verb writes through `s` afterward
  (`gate.commit_and_publish` is never called from `cmd_show`, `cmd_status`,
  or `cmd_next`), so dropping `store.list`'s lease side effect (`s.
  leased_ref`/`leased_sha`/`leased_item`) there is safe — those three verbs
  never use it.
- **`flow.tl`, `priority.tl`, `health.tl`, `gitready.tl`, `intake.tl`,
  `action.tl`, `gitgate.tl`, `gitverdict.tl`, `gitverbs.tl`, `gitgraph.tl`,
  `gitcompare.tl`, `gitfsck.tl` need NO internal changes at all** — they
  keep calling exactly the functions they call today; only the ultimate
  SOURCE of the `{Item}` list two of them start from changes. This is what
  makes item (e) ("delete `flow.tl`/`priority.tl`") not just hard to
  complete but unnecessary: both modules stay exactly as they are,
  permanently load-bearing for every mutation verb's write-time gates.

### 6. Revised follow-ups

One item does the entire migration: **(a)** — retitled, its spec rewritten
to add `cachequery.items` and the three call-site swaps, with the
field-equivalence proof above as its evidence. Items **(b)**, **(c)**,
**(e)** as originally filed have no code left for them to do — each is
rewritten to record why, with a recommendation to resolve each
`not-planned` citing this research rather than leave them open for a
builder to discover the same thing independently; **(d)** keeps one small,
real task (`gitcompare.tl:104`'s second whole-board read), `blocked_by` (a).
