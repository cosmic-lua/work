--- `gitboard migrate`'s step 2: one parent's `order` from its
--- children's `beats` edges — the board included, since it holds its
--- outcomes' list exactly like any other parent holds its children's.
--- Pure: no store, no git, nothing but the item list `_work.gitmigrate`
--- already loaded through `store.list_for_migrate`. Split out of
--- `_work.gitmigrate_plan` to keep that file under the line cap, and
--- because the topological sort is independently testable with no
--- fixture repository at all.
---
--- Only a DIRECT `beats` edge between two of the SAME parent's children
--- counts: a child with an edge to or from a sibling is a participant,
--- the transitive closure over every participant's edges is a
--- topological order (winners first — the source of a `beats` edge
--- outranks its target), and ties among otherwise-equal participants
--- break by age (KSUID id ascending, the same fallback
--- `_work.rank`'s own comparator uses with no seed). An edge whose
--- other end is not a sibling, or where either end is done, is DROPPED
--- rather than applied — the caller reports both back to whoever runs
--- the migration.
local item = require("_work.item")

--- One `beats` edge this migration could not apply, and why: not a
--- sibling under the same parent, or one side already done.
local record Dropped
  winner: string
  loser: string
  reason: string
end

--- One parent's computed order: the winners-first topological order
--- over its participating children (possibly empty — a parent with no
--- `beats` edges among its children ranks none of them), every dropped
--- edge, and — only when a cycle left some participants unsortable —
--- their ids, sorted, so the caller can name them for a human to rank
--- by hand; `order` is then empty too.
local record Result
  order: {string}
  dropped: {Dropped}
  cycle: {string}
end

--- The `beats` targets `it` itself names, kind -> id -> content on
--- `it.other_edges`; empty for an item with none.
--- @param it item.Item The item
--- @return {string: string} Target id -> content ("" for a bare marker)
local function beats_of(it: item.Item): {string: string}
  return (it.other_edges or {}).beats or {}
end

--- One parent's `order`: gather every child with a `beats` edge to or
--- from a sibling, drop what does not qualify, then topologically sort
--- the survivors.
--- @param child_ids {string} P's children, in any order
--- @param index {string: item.Item} Every item by id
--- @return Result
local function order_for(child_ids: {string}, index: {string: item.Item}): Result
  local in_group: {string: boolean} = {}
  for _, id in ipairs(child_ids) do
    in_group[id] = true
  end
  local dropped: {Dropped} = {}
  local out_edges: {string: {string: boolean}} = {}
  local participants: {string: boolean} = {}
  for _, cid in ipairs(child_ids) do
    local c = index[cid]
    if c ~= nil then
      for target in pairs(beats_of(c)) do
        if not in_group[target] then
          dropped[#dropped + 1] = {winner = cid, loser = target, reason = "not a sibling"}
        else
          local t = index[target]
          if not item.is_open(c) or (t ~= nil and not item.is_open(t)) then
            dropped[#dropped + 1] = {winner = cid, loser = target, reason = "done item"}
          else
            out_edges[cid] = out_edges[cid] or {}
            out_edges[cid][target] = true
            participants[cid] = true
            participants[target] = true
          end
        end
      end
    end
  end
  -- Kahn's algorithm: in-degree per participant (how many siblings
  -- beat it), pick the zero-in-degree node with the smallest (oldest)
  -- id each round, then remove its outgoing edges.
  local indegree: {string: integer} = {}
  for pid in pairs(participants) do
    indegree[pid] = 0
  end
  for _, targets in pairs(out_edges) do
    for target in pairs(targets) do
      indegree[target] = (indegree[target] or 0) + 1
    end
  end
  local remaining: {string: boolean} = {}
  local total = 0
  for pid in pairs(participants) do
    remaining[pid] = true
    total = total + 1
  end
  local order: {string} = {}
  for _ = 1, total do
    local pick: string = nil
    for pid in pairs(remaining) do
      if (indegree[pid] or 0) == 0 and (pick == nil or pid < pick) then
        pick = pid
      end
    end
    if pick == nil then
      break
    end
    order[#order + 1] = pick
    remaining[pick] = nil
    for target in pairs(out_edges[pick] or {}) do
      indegree[target] = (indegree[target] or 0) - 1
    end
  end
  if next(remaining) ~= nil then
    local cycle: {string} = {}
    for pid in pairs(remaining) do
      cycle[#cycle + 1] = pid
    end
    table.sort(cycle)
    return {order = {}, dropped = dropped, cycle = cycle}
  end
  return {order = order, dropped = dropped, cycle = {}}
end

local record gitmigrate_order
  type Dropped = Dropped
  type Result = Result
  order_for: function(child_ids: {string}, index: {string: item.Item}): Result
end

local M: gitmigrate_order = {
  order_for = order_for,
}

return M
