## Evidence

Parent item 3Isoczw9JmeVhX6X6NvBZCtZ5l7's coverage table (see its
`## Findings`) classifies every function these three modules call:
`gitready` uses `flow.by_id/is_blocked/item_problems/ready_gaps/role` and
`prio.is_placed/positions`; `intake` uses `flow.in_state/is_blocked/
ready_gaps/roots/untriaged` and `prio.is_placed`; `action` uses
`flow.DOING_LIMIT/by_id/doing_refusal/in_state/is_blocked/ready_gaps/
STAGE_*/stage_rank/substate/unified` and `prio.is_placed/positions`. All are
`same` except `by_id` (superseded) and `ready_gaps` (unrelated to the
index — stays a direct call to `_work.spec.ready_gaps`, not migrated).
`action`'s `unified` and `stage_rank` calls need the lift/tie-break helper
item (a) builds.

## Change

`_work/cacheread.tl` (built by follow-up (a), which this item is
`blocked_by`) already exposes every function these three files need.
Migrate `gitready`, `intake`, and `action`: swap
`require("_work.flow")`/`require("_work.priority")` for
`require("_work.cacheread")`, and each call site's `{Item}` argument for
the cache handle. `ready_gaps` call sites are untouched (still
`_work.spec.ready_gaps`, direct or via whatever re-export `cacheread`
keeps for it). `DOING_LIMIT`/`STAGE_*` constant references stay pointed at
`flow.tl` until item (e) relocates them. Extend `cacheread`'s differential
tests (or add module-specific ones) only if these three exercise a shape
the (a) tests do not already cover — cite which, if any, in this item's own
findings.

## Non-goals

Changing any view's definition or the STRICT schema; changing `gitready`'s,
`intake`'s, or `action`'s printed output; touching any file outside these
three plus `_work/cacheread.tl`'s call sites (never `cacheread.tl` itself —
if a needed function is missing, that is a gap in (a) to raise, not to
patch here); deleting `flow.tl`/`priority.tl`.
