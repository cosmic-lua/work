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

## Findings (research pass, 2026-09-05)

**Re-run confirms the Evidence exactly**, with normal day-to-day drift:
12 `CREATE VIEW`s (same 12 names), the 13-importer grep (same 13 files),
`flow.tl` 490 / `priority.tl` 478 / `cachequery.tl` 135 / `index_test.tl`
323 / `index_priority_test.tl` 225 lines (all unchanged), 19 test cases
(15+4, unchanged). Timing re-run on the production board (930 refs, not
929 — one ref moved since the prior count): `show` 236 ms (was 233),
`store.list` 149.8 ms (146), `gitread.list` 128.7 ms (123), `cat_file_batch`
107.3 ms inclusive over 4 calls (102), `read_specs` 16.8 ms (19),
`cache.open` 15.0 ms (15); `find` 30 ms end to end (29). **One drift worth
recording**: `priority.tl`'s `M` table actually exports **11** functions,
not 10 (`index_of, dominated, beaten_set, has_out_edge, positions, key_of,
order_of, is_placed, sorted, cycle_problems, edge_refusal`) — `edge_refusal`
is the eleventh. `flow.tl`'s 17 is exact once `ready_gaps` (a re-export of
`_work.spec.ready_gaps`, unrelated to graph/state derivation) is excluded
from the 18 keys in its `M` table.

### 1. Coverage table

Proven `same` rows were diffed live against the production board (930
items, 244 `blocked_by` edges) via a throwaway script wrapping
`_work.index.open` + `_work.index_priority.ensure_views` next to
`_work.priority`/`_work.flow`'s own derivation; counts below are that run's
output.

**`_work/flow.tl` (17 functions)**

| function | same/none | view or query | evidence |
|---|---|---|---|
| `is_doing` | same | `state` view (`state = 'doing'`) | 0/201 mismatches (open items only — `state`'s CASE checks `resolution` first, same as `is_doing`'s callers always do) |
| `substate` | same | `substate` view (no `queued` arg — already documented as the store's unsupplied-argument behavior) | 0/930 mismatches |
| `stage_rank` | none | no view composes `state`+`substate`+`key` into one rank yet | — |
| `unified` | none | needs `stage_rank` (above) plus per-bucket blocker-lift and the seeded tie-break, neither modeled in SQL | — |
| `by_id` | none (superseded) | the cache connection itself replaces a per-call in-memory index; nothing needs a Lua `{id: Item}` table once a handle is open | — |
| `has_open_children` | same | `containers` view / `EXISTS` query | 0/930 mismatches |
| `role` | same | composed from `containers` + `roots` views | 0/930 mismatches |
| `in_state` | same (membership only) | `workable` ⋈ `state` | membership proven via `doing`/`todo` counts (3 doing, matches exactly); **order** is none — see the order-wall finding below |
| `doing_refusal` | same | `COUNT(*) FROM workable w JOIN state s ON s.id=w.id WHERE s.state='doing'` vs `DOING_LIMIT`, plus a trivial `items.key` check for the lane-repair carve-out | lua=3, sql=3 |
| `is_blocked` | same | `SELECT 1 FROM edges e JOIN open_items o ON o.id=e.to_id WHERE e.kind='blocked_by' AND e.from_id=?` | 0/930 mismatches |
| `binds` | same | `EXISTS(SELECT 1 FROM open_items WHERE id=?)` — the base case of the query above | structurally identical to the proven `is_blocked` query; not independently diffed |
| `waits_on` | none | no transitive `blocked_by` closure view exists (only `dominates`, over `beats`); **also**, both live call sites (`gitcompare`'s `compare`, `gitgraph`'s `block`) ask it about a candidate edge **before** it is committed — see the write-path finding below | — |
| `root_of` | same | `ancestors` (from `index_priority`) ⋈ `roots`, plus a self-check for an item that is already a root | 0/930 mismatches |
| `item_problems` | same | `dangling_parents` + `broken_chains` queries, already in `index.tl` | 0/0 on this board (no problems today); already differentially proven with non-zero fixtures by `index_test.tl` |
| `graph_problems` | same, as a **superset** | `index.problems()` = `graph_problems` ∪ `key_duplicates` (already proven by `index_test.tl`'s `assert_superset`) | 0 extra lines on this board (no key collisions today) |
| `roots` | same (placement/live/held) | `roots` ⋈ `unplaced` ⋈ `ancestors` ⋈ `items.held` | 12 placed open roots, lua=sql; **order** carries the same lift caveat as `in_state`/`unified` whenever a placed root is itself lifted by an open blocker (not exercised by today's 12, not proven absent in general) |
| `untriaged` | same | `roots` ∖ `containers` ∩ `unplaced`, ordered by id ascending (everything in it is unplaced, so band/own never differ and lift never applies) | exact id-set match, 2=2 |

`ready_gaps` is a re-export of `_work.spec.ready_gaps` (checks spec markdown
text, not graph/state) — out of scope for this migration; callers keep
calling it directly.

**`_work/priority.tl` (11 functions — see the count note above)**

| function | same/none | view or query | evidence |
|---|---|---|---|
| `index_of` | none (superseded) | same rationale as `by_id` | — |
| `dominated` | same | `SELECT loser FROM dominates WHERE winner=?` | 0/50 sampled |
| `beaten_set` | same | `SELECT DISTINCT e.to_id FROM edges e JOIN items i ON i.id=e.to_id WHERE e.kind='beats'` | lua=59, sql=59 |
| `has_out_edge` | same | `SELECT 1 FROM edges e JOIN items i2 ON i2.id=e.to_id WHERE e.kind='beats' AND e.from_id=?` | 0/930 mismatches |
| `positions` | same (`placed`/`band`/`own` only) | `own` + `band` + `unplaced` views | 0/930 mismatches on all three fields; **`lift_band`/`lift_own`/`lifted_from`/`unblocks` are none** — see below |
| `key_of` | same | `index_priority.position_of` already returns exactly this pair | proven via `positions` row above |
| `order_of` | none | same lift gap as `positions` | — |
| `is_placed` | same | `unplaced` view / `position_of`'s first return | proven via `roots`/`untriaged` above |
| `sorted` | none, for the full contract | `order_ids` matches only band/own ordering with no seed and no active lift; diverges on this board — see below | first divergence at rank 10 of 930 (ids `3Ip8zrCb`/`3Ip8wKdw` swap) |
| `cycle_problems` | same | `priority_cycles` (`index.tl`) / `cycle_ids` (`index_priority.tl`) | 0=0 on this board; non-zero already proven by fixtures |
| `edge_refusal` | same in principle, kept in Teal in practice | composable via `EXISTS(SELECT 1 FROM dominates WHERE winner=<loser> AND loser=<winner>)` | not independently diffed (no live cycle scenario); its one caller needs it evaluated against a not-yet-committed edge — see below |

### 2. The order wall — two separate gaps, not one

**(a) The seeded tie-break.** Confirmed by grep AND by running it:
`cosmic.sqlite`'s `Database` record (`/home/user/cosmic/cosmic/sqlite/init.tl`)
exposes `prepare/query/query_one/exec/exec_script/transaction/savepoint/
last_insert_rowid/changes/close` — no `create_function`, `create_aggregate`,
or `create_collation`. A runtime probe confirms it: `type(db.create_function)`
is `nil`, and calling it raises `attempt to call a nil value (method
'create_function')`. The capability exists one layer down — the raw
`cosmo.lsqlite3` binding **does** declare `create_function`/`create_aggregate`/
`create_collation` (`o/_types/types_gen/cosmo/lsqlite3.d.tl` lines 108/129/149)
— but `_work/*.tl` uses `cosmic.sqlite`, never reaches for `cosmo.lsqlite3`
directly, and the wrapper does not forward it. **Decision: the seeded
`fnv32` tie-break stays in Teal**, applied to rows already ordered by
band/own from SQL.

**(b) Blocker lift is a second, bigger gap the spec did not anticipate.**
`_work/index_priority.tl`'s own header says blocker-lift is "deliberately
NOT modeled," true only on boards with no `blocked_by` edges. The production
board carries **244** `blocked_by` edges, and the divergence is measurable,
not theoretical: `priority.sorted`'s unseeded order and `index_priority.
order_ids` **diverge starting at rank 10 of 930** (two items swap because one
is lifted by an open blocker `order_ids` cannot see). Because `unified` and
`in_state`'s printed order is exactly what `next`/`show` render — and this
item's own Non-goals forbid changing a verb's printed output — **lift must
also stay in Teal**, not just the tie-break. The good news: lift does not
need a new recursive view (which would touch a Non-goal). It needs two lean
queries against tables that already exist — `SELECT id FROM open_items`
and `SELECT from_id, to_id FROM edges WHERE kind='blocked_by'` — feeding
`priority.lift`'s existing walk, adapted to consume those thin rows plus the
SQL-sourced `own`/`band` map instead of full `{Item}` + `index_of`. No view
or schema changes either way.

**Revised decision**: `own`, `band`, and `placed` come from
`index_priority`'s existing views; blocker lift and the seeded tie-break
both stay in Teal, fed by two small queries rather than a full `store.list`.

### 3. The seam

`_work/cachequery.tl` stays at 135 lines (unchanged); the migrated readers
go into a new sibling, **`_work/cacheread.tl`** — 20-odd functions with doc
comments plus the lift/tie-break helper above will cross the 500-line cap
if folded into `cachequery.tl`.

**A wiring gap must be closed before any of this can work**:
`_work.index_priority.ensure_views` — which creates the `has_edge`, `own`,
`ancestors`, `band`, `unplaced` views — is called nowhere outside its own
test (`grep -rn "ensure_views" _work cmd`, only `index_priority.tl` and
`index_priority_test.tl` match). `_work/cache.tl`'s `rebuild` runs
`index.DDL` and `cachedb.EXTRA_DDL` but never `index_priority.EXTRA_DDL`,
and `_work/cachedb.tl`'s `expected_schema_fingerprint` builds the same two,
skipping the third. **`o/board.db` today does not carry the priority
views at all.** This is a small, precise fix (add one more
`db:exec_script(index_priority.EXTRA_DDL)` call in both places;
`schema_fingerprint` already derives from `sqlite_master`, so no
`SCHEMA_VERSION` bump is mechanically required) — assigned to follow-up (a)
below, since it is the first to need it.

**Verbs that must keep the Teal path** (not a should-move-later; a
structural fit problem, matching what step 3 asked to name):

- **`gitfsck`** — its only flow usage is `flow.by_id` (already "none,
  superseded" in the table above), and its entire purpose is auditing raw
  git truth independent of, and in spite of, a possibly-corrupt cache.
  Keeps `store.list` + `flow.by_id` exactly as today; needs **no** follow-up
  work at all.
- **`gitcompare`**'s `compare` verb (`_work/gitcompare.tl:29-104`) calls
  `prio.index_of`/`prio.edge_refusal` on an **in-memory graph that already
  has the candidate edge added**, to decide before commit whether it would
  close a cycle — the persistent cache reflects only committed state and
  cannot represent a hypothetical edge without a speculative write this
  research is not scoped to design. That pre-write check keeps
  `store.list` + `prio.index_of`/`edge_refusal` unchanged. Its **post-write**
  reporting line (`gitcompare.tl:104`, `prio.key_of(prio.positions(store.list(s)...), winner)`,
  a second whole-board `store.list` paid only to print one item's band/own)
  **can** move to a single cache-backed `position_of` read once (a) lands —
  the write already patched the cache by the time this line runs.
- **`gitgraph`**'s `block`/`unblock` verb (`_work/gitgraph.tl:238`) calls
  `flow.waits_on` in the same shape as `gitcompare`'s pre-write check
  ("Bounded on the add path only: `flow.waits_on` just decided this," the
  module's own comment). Cluster (d)'s follow-up should apply the same
  committed-vs-candidate test call-site by call-site rather than assume a
  blanket function-level swap; `flow.root_of`/`flow.has_open_children`
  elsewhere in the same file are ordinary reads and migrate cleanly.
- A **fresh clone before `sync`** pays `cache.open`'s existing cold-rebuild
  cost transparently (no cache file → `rebuild` → full `store.list`); no
  caller-side special-casing is needed, this is already how `cache.open`
  works today.

### 4. Follow-ups

Filed as the five sibling items under this parent (a: `cacheread` seam plus
gitshow + gitview; b: gitready + intake + action; c: gitgate + gitverdict +
gitverbs; d: gitgraph + health, with gitcompare's pre-write check and gitfsck
staying on the Teal path; e: delete flow.tl/priority.tl). Because all four
of (a)-(d) migrate into the **same** new file (`_work/cacheread.tl`), true
file-disjointness among them is only possible if one of them creates it and
the others only consume it: **(a) creates `_work/cacheread.tl`** with every
function classified `same` above (from both tables) plus the lift/tie-break
helper from the order-wall decision — a deliberate, larger-than-"gitshow+
gitview" scope for (a), stated so no judgment is left for its builder. (b),
(c), (d) then touch only their own importer files (a `require` line and one
argument per call site) and are `blocked_by` (a); they do not touch
`cacheread.tl` again, so they remain file-disjoint from each other. (e) is
`blocked_by` (a)-(d) as `## Change` already states, and additionally
relocates `flow.tl`'s constants (`DOING_LIMIT`, `STAGE_*`) and
`priority.tl`'s `Position` record, since importers still reference them
directly after the functions move.
