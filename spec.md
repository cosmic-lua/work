## Evidence

Parent item 3Isoczw9JmeVhX6X6NvBZCtZ5l7's rigor pass produced a full,
line-by-line inventory of `gitgraph.tl` (reproduced below) and confirmed
the same for `gitcompare.tl` and `gitfsck.tl`; `health.tl` is a pure
function module (0 `store.list` calls) reached only from `gitview.tl`
(migrated by «VkzD_q8u2») and `action.tl` (needs no change per «OJnW_MLge»'s
finding).

**`gitgraph.tl`** — every mutation (`new`, `attach`, `block`/`unblock`,
`set`) loads its own `store.list` for its commit lease:

| line | call | why it stays |
|---|---|---|
| 77, 140, 224 | `flow.by_id(all)` | mutation-fed; `all` already in memory |
| 152 | `flow.root_of(parent_item, index)` | reads committed state, but `all`/`index` are already loaded for this same commit — no duplicate read to remove |
| 185 | `flow.has_open_children(all, id)` | same — decides only the confirmation line's wording, post-commit, from the pre-commit `all` already in memory |
| 238 | `flow.waits_on(index, blocker, id)` | validates the CANDIDATE `blocked_by` edge before it is written; the persistent cache reflects only committed state and cannot represent it |
| 288 | `prio.is_placed(prio.positions(all), blocker)` | guidance text only, from the same already-loaded `all` |

**`gitcompare.tl`** (`compare`/`hold`/`unhold`, all mutations): `prio.
index_of`/`edge_refusal` (lines 35, 59) validate a candidate `beats` edge
before commit, the same shape as `gitgraph.tl:238` — cannot move.
`gitcompare.tl:104`'s `prio.key_of(prio.positions(store.list(s) or all),
winner)` is a genuine SECOND `store.list`, paid only to print the winner's
post-commit band/own — but under the parent's revised design (hydrate, not
reimplement), the fix is not a bespoke `position_of` cache read: it is
simply replacing that second `store.list(s)` with a `cache.open`+
`cachequery.items` call (built by «VkzD_q8u2»), still calling the
UNCHANGED `prio.key_of(prio.positions(...), winner)` on the result — one
fewer git read, zero risk of drift, since the same Lua runs either way.

**`gitfsck.tl`**: unchanged from the parent's original finding — its sole
purpose is auditing raw git truth independent of, and in spite of, a
possibly-corrupt cache; it must never read the cache at all.

## Change

1. `gitgraph.tl`, `gitcompare.tl`'s pre-write checks, `gitfsck.tl`,
   `health.tl`: no change.
2. `gitcompare.tl:104` only: replace `store.list(s)` with `cache.open(s.
   root)` + `cachequery.items(c)` (from «VkzD_q8u2», which this item is
   `blocked_by`), keeping `prio.key_of(prio.positions(...), winner)`
   exactly as written today over the result. The cache is current at that
   point because the write just patched it (`cache.after_save`).
3. Test: the existing `_work/gitcompare_test.tl` cases pass unchanged (the
   printed band/own line is byte-identical); add one case asserting the
   post-write report calls `store.list` zero times (module-table counting
   stub, the pattern #18 introduced).

## Non-goals

Changing `gitcompare`'s, `gitgraph`'s, or `gitfsck`'s pre-write cycle
checks or refusal behavior in any way; changing any printed output;
touching `flow.tl`/`priority.tl`.
