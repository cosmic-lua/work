--- The intake half of the next-action ordering: everything upstream
--- of a claim. `_work.action` decides the in-flight half — land,
--- review, finish, pull — and consults this only when none of those
--- has work, so nothing here ever outranks moving something that is
--- already in flight.
---
--- The rungs, in order: triage what arrived, refine the top of todo
--- toward the spec bar, and decompose an undriven root. Triage first
--- because it is the cheap decision (is this real, and under which
--- outcome) and the starvable one — an unplaced capture is invisible
--- to every queue, and an inbox nobody empties is a channel that only
--- takes. Refinement is where the expensive judgment goes, and it can
--- never starve: the top of todo is always there.
local decision = require("_work.decision")
local flow = require("_work.flow")
local item = require("_work.item")
local rank = require("_work.rank")

local type Item = item.Item
local type Action = decision.Action
local type Specs = {string: string}

--- The highest-ranked todo item worth refining: ranked and failing the
--- spec bar. `_work.flow`'s stage order already keeps a doing item out
--- of this queue.
--- @param items {Item} All items
--- @param specs Specs Spec sidecar body, by item id
--- @param ranks {string: rank.Rank} Rank by item id
--- @return Item | nil The item to refine
local function refinable(items: {Item}, specs: Specs,
    ranks: {string: rank.Rank}): Item | nil
  for _, i in ipairs(flow.in_state(items, "todo", ranks)) do
    if rank.is_ranked(ranks, i.id)
    and #flow.ready_gaps(specs[i.id] or "") > 0 then
      return i
    end
  end
  return nil
end

--- The intake decision, or nil when intake has nothing to offer.
--- @param items {Item} All items
--- @param specs Specs Spec sidecar body, by item id
--- @param ranks {string: rank.Rank} Rank by item id
--- @param root_order {string} The board's root list
--- @return Action | nil The decision
local function intake_action(items: {Item}, specs: Specs,
    ranks: {string: rank.Rank}, root_order: {string}): Action | nil
  local triage = flow.untriaged(items, root_order)
  if #triage > 0 then
    return {
      kind = "triage",
      item = triage[1],
      reason = ("%d root(s) await triage — rank it among the roots "
        .. "(`rank`), attach it under a ranked root, or end it"):format(
        #triage),
    }
  end
  local refining = refinable(items, specs, ranks)
  if refining ~= nil then
    return {
      kind = "refine",
      item = refining,
      reason = "the highest-ranked todo item that misses the spec bar — "
      .. "refine it until `check` passes",
    }
  end
  -- A held root — its win condition verified — is walked past exactly
  -- like one with live work: nothing to decompose until evidence
  -- filed under it clears the hold.
  local ordered, live, held = flow.roots(items, root_order)
  for _, g in ipairs(ordered) do
    if not live[g.id] and not held[g.id] then
      return {
        kind = "intake",
        item = g,
        reason = ("%s has no live work — decompose it"):format(
          g.id:sub(1, 8)),
      }
    end
  end
  -- Only worth saying when there ARE ranked roots: with none, "every
  -- open root has live work" is vacuously true and tells a session
  -- nothing about why it has been handed no work.
  if #ordered > 0 then
    return {kind = "intake", reason = "every open root has live work — "
      .. "work backwards from the highest-ranked one with slack"}
  end
  return nil
end

local record intake
  type Specs = Specs
  refinable: function(items: {Item}, specs: Specs,
  ranks: {string: rank.Rank}): Item | nil
  intake_action: function(items: {Item}, specs: Specs,
  ranks: {string: rank.Rank}, root_order: {string}): Action | nil
end

local M: intake = {
  refinable = refinable,
  intake_action = intake_action,
}

return M
