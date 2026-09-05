--- The intake half of the next-action ordering: everything upstream
--- of a claim. `_work.action` decides the in-flight half — land,
--- review, finish, pull — and consults this only when none of those
--- has work, so nothing here ever outranks moving something that is
--- already in flight.
---
--- The rungs, in order: triage what arrived, refine the top of todo
--- toward the spec bar, and decompose an undriven outcome. Triage first
--- because it is the cheap decision (is this real, and under which
--- outcome) and the starvable one — an unplaced capture is invisible
--- to every queue, and an inbox nobody empties is a channel that only
--- takes. Refinement is where the expensive judgment goes, and it can
--- never starve: the top of todo is always there.
---
--- Reads the board database directly (`_work.read`): `triage` for the
--- captured queue, `_work.read.queue` (filtered to the todo/repair
--- stages) plus `is_ranked` for the refinement candidate, and
--- `outcomes` — whose own `live` flag already answers "has live work"
--- — for decomposition. Age order throughout; the seeded tie-break is
--- `_work.action`'s alone, applied only to the in-flight half.
local decision = require("_work.decision")
local flow = require("_work.flow")
local index = require("_work.index")
local item = require("_work.item")
local read = require("_work.read")

local type Item = item.Item
local type Index = index.Index
local type Action = decision.Action
local type Specs = {string: string}

--- The highest-ranked todo item worth refining: ranked and failing the
--- spec bar, in queue order (todo and lane-repair stages both — the
--- same bucket `_work.read.queue`'s stage column keeps below review).
--- @param c Index An index with `_work.readddl.ensure_views` applied
--- @param by_id {string: Item} Every item, by id
--- @param specs Specs Spec sidecar body, by item id
--- @return Item | nil The item to refine
--- @return string Error message
local function refinable(c: Index, by_id: {string: Item},
    specs: Specs): Item | nil, string
  local rows, err = read.queue(c)
  if rows == nil then
    return nil, err
  end
  for _, row in ipairs(rows) do
    if row.stage >= flow.STAGE_REPAIR then
      local ranked, rerr = read.is_ranked(c, row.id)
      if ranked == nil then
        return nil, rerr
      end
      if ranked and #flow.ready_gaps(specs[row.id] or "") > 0 then
        return by_id[row.id], ""
      end
    end
  end
  return nil, ""
end

--- The intake decision, or nil when intake has nothing to offer.
--- @param c Index An index with `_work.readddl.ensure_views` applied
--- @param items {Item} All items
--- @param specs Specs Spec sidecar body, by item id
--- @return Action | nil The decision
--- @return string Error message
local function intake_action(c: Index, items: {Item},
    specs: Specs): Action | nil, string
  local by_id = item.by_id(items)
  local triage, terr = read.triage(c)
  if triage == nil then
    return nil, terr
  end
  if #triage > 0 then
    return {
      kind = "triage",
      item = by_id[triage[1]],
      reason = ("%d outcome(s) await triage — rank it among the outcomes "
        .. "(`rank`), attach it under a ranked outcome, or end it"):format(
        #triage),
    }, ""
  end
  local refining, rferr = refinable(c, by_id, specs)
  if rferr ~= "" then
    return nil, rferr
  end
  if refining ~= nil then
    return {
      kind = "refine",
      item = refining,
      reason = "the highest-ranked todo item that misses the spec bar — "
      .. "refine it until `check` passes",
    }, ""
  end
  local ordered, oerr = read.outcomes(c)
  if ordered == nil then
    return nil, oerr
  end
  for _, o in ipairs(ordered) do
    if not o.live then
      return {
        kind = "intake",
        item = by_id[o.id],
        reason = ("%s has no live work — decompose it"):format(
          o.id:sub(1, 8)),
      }, ""
    end
  end
  -- Only worth saying when there ARE ranked outcomes: with none, "every
  -- open outcome has live work" is vacuously true and tells a session
  -- nothing about why it has been handed no work.
  if #ordered > 0 then
    return {kind = "intake", reason = "every open outcome has live work — "
      .. "work backwards from the highest-ranked one with slack"}, ""
  end
  return nil, ""
end

local record intake
  type Specs = Specs
  refinable: function(c: Index, by_id: {string: Item}, specs: Specs):
  Item | nil, string
  intake_action: function(c: Index, items: {Item}, specs: Specs):
  Action | nil, string
end

local M: intake = {
  refinable = refinable,
  intake_action = intake_action,
}

return M
