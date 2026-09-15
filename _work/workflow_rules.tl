--- Pure workflow rules shared by native verbs and raw snapshot validation.
local item = require("_work.item")
local itemtree = require("_work.itemtree")

local record ChildState
  any: boolean
  open: item.Item | nil
  completed: boolean
end

--- Child facts used by outcome completion and raw final-state validation.
local function child_state(items: {item.Item}, parent: string): ChildState
  local out: ChildState = {any = false, open = nil, completed = false}
  for _, child in ipairs(items) do
    if child.parent == parent then
      out.any = true
      if item.is_open(child) and out.open == nil then out.open = child end
      if child.resolution == "completed" then out.completed = true end
    end
  end
  return out
end

--- Whether `session` helped build or specify an item under review.
local function distance_refusal(it: item.Item, session: string): string | nil
  if session == "" then return nil end
  for _, name in ipairs(it.builders or {}) do
    if name == session then
      return ("REFUSED: %s built/specced %s — the verdict needs a fresh "
        .. "context; recording it anyway needs --force --why"):format(
        session, it.id:sub(1, 8))
    end
  end
  for _, name in ipairs(it.speccers or {}) do
    if name == session then
      return ("REFUSED: %s built/specced %s — the verdict needs a fresh "
        .. "context; recording it anyway needs --force --why"):format(
        session, it.id:sub(1, 8))
    end
  end
  return nil
end

--- A research handover must have some specification to hand over.
local function research_spec_refusal(id: string,
    prose: itemtree.Spec): string | nil
  if prose.change ~= "" or prose.non_goals ~= "" then return nil end
  return ("%s has no spec — a research handover hands the spec over, "
    .. "and there is none"):format(id:sub(1, 8))
end

--- Worked completion needs acceptance unless this is an audited repair.
local function completion_review_refusal(it: item.Item,
    force: boolean): string | nil
  if force or (it.verdict or "") == "accept" then return nil end
  if (it.pr or 0) ~= 0 then
    return ("%s has PR #%d awaiting a verdict — done after an accept, "
      .. "or `drop` releases the handover"):format(it.id:sub(1, 8), it.pr or 0)
  end
  if #(it.builders or {}) > 0 then
    return ("%s has no PR and no accept — an evidence-only item takes "
      .. "a verdict too; record one (`gitboard verdict`), or end it "
      .. "without review via --force --why"):format(it.id:sub(1, 8))
  end
  return nil
end

--- Pure shape of an accepted or force-completed research landing.
local function research_landing_refusal(it: item.Item, reason: string,
    landed: string, force: boolean): string | nil
  local result = it.result or ""
  if reason ~= "completed" or (it.handover_head or "") ~= ""
  or result == "" then return nil end
  if (it.verdict or "") ~= "accept" then
    if landed ~= "" then return "--landed belongs to completed accepted work" end
    return nil
  end
  if (it.verdict_head or "") ~= result then
    return "acceptance must name the current research handover"
  end
  if landed == "" and not force then
    return "completed accepted work names its landed commit with --landed"
  end
  if landed ~= "" and landed ~= result and not force then
    return "research landing does not name published result"
  end
  return nil
end

local record Module
  type ChildState = ChildState
  child_state: function({item.Item}, string): ChildState
  distance_refusal: function(item.Item, string): string
  research_spec_refusal: function(string, itemtree.Spec): string
  completion_review_refusal: function(item.Item, boolean): string
  research_landing_refusal: function(item.Item, string, string,
  boolean): string
end
local M: Module = {
  child_state = child_state,
  distance_refusal = distance_refusal,
  research_spec_refusal = research_spec_refusal,
  completion_review_refusal = completion_review_refusal,
  research_landing_refusal = research_landing_refusal,
}
return M
