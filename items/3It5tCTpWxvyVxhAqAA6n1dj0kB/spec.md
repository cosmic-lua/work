## Evidence

Parent item 3Isoczw9JmeVhX6X6NvBZCtZ5l7's research found this cluster is
NOT a uniform swap, unlike (a)-(c):

- **`gitfsck`**'s only flow usage is `flow.by_id` (`_work/gitfsck.tl:39`),
  already classified "none, superseded" — and its whole purpose is
  auditing raw git truth independent of a possibly-corrupt cache
  (`store.list`, never `cache.open`). It needs **no** change.
- **`gitcompare`**'s `compare` verb (`_work/gitcompare.tl:29-104`) calls
  `prio.index_of`/`prio.edge_refusal` on an in-memory graph that already
  has the CANDIDATE edge added, to decide before commit whether recording
  it would close a cycle — the persistent cache reflects only committed
  state, so this pre-write check keeps `store.list` +
  `prio.index_of`/`edge_refusal` exactly as today. Its post-write report
  line (`gitcompare.tl:104`, a second whole-board `store.list` paid only
  to print the winner's new band/own) can move to one cache-backed
  `position_of` read, since `cache.after_save` has already patched the
  file by the time that line runs.
- **`gitgraph`**'s `block`/`unblock` (`_work/gitgraph.tl:238`) calls
  `flow.waits_on` in the identical shape ("Bounded on the add path only:
  `flow.waits_on` just decided this," per the file's own comment) —
  the same pre-write-candidate-edge pattern as `gitcompare`. `gitgraph`'s
  other calls (`flow.by_id`, `flow.has_open_children`, `flow.root_of`) are
  ordinary reads and are `same`/superseded per the coverage table.
- **`health`**'s only flow usage is `flow.by_id` (superseded) and
  `flow.waits_on` (self-reachability, for blocker-cycle detection) — the
  latter is `none`: no transitive `blocked_by` closure view exists (only
  `dominates`, over `beats`).

## Change

1. `gitfsck`: no change.
2. `gitgraph`: migrate `flow.by_id`/`flow.has_open_children`/`flow.root_of`
   call sites to `_work.cacheread` (built by follow-up (a), which this
   item is `blocked_by`) and the cache handle. Leave the `flow.waits_on`
   call inside `block`/`unblock`'s cycle check on `store.list` +
   `flow.waits_on` exactly as today — it is validating a not-yet-committed
   edge, the same category as `gitcompare`'s check below.
3. `gitcompare`: leave the pre-write cycle check
   (`prio.index_of`/`edge_refusal` over `store.list`'s freshly loaded,
   in-memory-mutated graph) exactly as today. Migrate only the post-write
   reporting call at `gitcompare.tl:104` to a single `cacheread.position_of`
   read against the cache handle (already patched by `cache.after_save` by
   this point in `cmd_compare`), replacing the second `store.list` +
   `prio.positions` over the whole board.
4. `health`: `flow.by_id` moves to `_work.cacheread`/the cache handle.
   `flow.waits_on`'s blocker-cycle check needs a genuinely new capability —
   either build it as a small Teal walk fed by two lean queries (`SELECT
   from_id, to_id FROM edges WHERE kind='blocked_by'`, no `{Item}`
   materialization), mirroring the lift helper's shape from follow-up (a),
   or leave `health` calling `flow.waits_on` over whatever `{Item}` list
   its caller already holds. Decide and record which, in this item's own
   findings — this research did not resolve it, since it is bigger than a
   mechanical swap.

## Non-goals

Changing any view's definition or the STRICT schema (item 4's Teal walk
uses only existing tables — `edges`, `open_items` — no new recursive view);
changing any of the four verbs' printed output, refusals, or cycle
detection; touching `gitcompare`'s or `gitgraph`'s pre-write cycle checks
beyond what is explicitly named above; touching any file outside this
cluster plus `_work/cacheread.tl`'s call sites; deleting `flow.tl`/
`priority.tl`.
