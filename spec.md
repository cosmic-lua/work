## Goal

`gitboard show`'s `triage N` line (and any other caller of
`_work/flow.tl`'s `untriaged()`) is meant to surface every unranked
child of the board so nothing sits unplaced and invisible. It misses
one whole class: an unranked board-level item that has ALREADY been
decomposed into open children. It is still exactly as stuck as a
bare unranked item — its own `bar` output says so — but the dashboard
never lists it, so a placement audit that trusts `show`'s summary
walks right past it.

## Evidence

`_work/flow.tl:410-422` (`untriaged`):

```lua
local function untriaged(items: {Item}): {Item}
  local index = it.by_id(items)
  local ranks = rank.positions(items)
  local out: {Item} = {}
  for _, i in ipairs(items) do
    if it.is_open(i) and is_outcome(i, index)
    and not has_open_children(items, i.id)     -- line 416
    and not rank.is_ranked(ranks, i.id) then
      out[#out + 1] = i
    end
  end
  return rank.sorted(out, ranks)
end
```

`is_outcome` (line 157-160) is purely structural — "parent is the
board" — so role (`outcome` vs `container`) plays no part; the
`has_open_children` clause on line 416 is what excludes an item, and
it excludes ANY board-level child with open children, ranked or not.

Reproduced live on the board today: `3IvKOEqsL8zOfTJMcenHpoMGzj7`
("Teal-aware structural search & replace...") is a direct child of the
board (`3IvHv59hv3R2ACeWQYKqg8GrU1X`), unranked, with 4 open children
(filed in the same session that opened it: `3IvKhphd`, `3IvKjF6W`,
`3IvKkQUb`, `3IvKlj8y`). Its own `show` output states the block
explicitly:

```
$ bin/gitboard show 3IvKOEqs
bar: 3IvKOEqs is a container, not workable
bar: 3IvKOEqs's outcome is unranked — rank the outcome first (`gitboard rank <outcome>`), or attach it under an item that already is
```

Yet `bin/gitboard show` (no id) prints no `triage` line at all right
now — there is nothing to report, because `has_open_children` is true
for this item and it is filtered out of `untriaged()`'s result before
`rank.sorted`. The only way this session found the item was a direct
read of `o/board.db`'s `items`/`ranks` tables outside `gitboard`
entirely, cross-referencing every board-level child against the
`ranks` table's rows for `parent = <board id>`.

Contrast with the friction log this session filed and ranked earlier
today (`Ecp3_zyae`): it WAS caught by `next`/`show`'s triage line,
because it had zero children at the time it was created — the same
unranked-child-of-the-board shape, but on the side of the
`has_open_children` check that still gets reported.

## Change

In `_work/flow.tl`'s `untriaged`, drop the `not has_open_children(...)`
condition — an item's own children being open says nothing about
whether IT is placed; `rank.is_ranked` already carries the placement
check. Confirm no caller relies on the current filtering-out behavior
as a feature (`_work/gitview.tl:210-212`'s dashboard render and any
other `flow.untriaged` call site) — if one specifically wants
"unranked AND childless" for its own reason, it should express that
itself rather than reuse a general-purpose `untriaged` that quietly
narrows the definition of "untriaged." Add a case to
`_work/flow_test.tl`: an unranked board-level item WITH an open child
still appears in `untriaged()`'s result.

## Non-goals

Not deciding whether `3IvKOEqs` itself should be ranked, attached
elsewhere, or left — that stays the goal owner's call once the item is
actually visible again.
