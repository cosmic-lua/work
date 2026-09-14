--- Shared graph predicates used by verbs and native bounded replay.
local item = require("_work.item")

--- The dependency chain from `on` back to `id`, or nil when none exists — the
--- witness `depend` refuses with, walked breadth-first and bounded by
--- `item.MAX_DEPTH` hops so an already-corrupt graph terminates too. Shared
--- with the bounded re-run, so the verb and the revalidation cannot diverge.
--- @param index item.Index Every item by id
--- @param id string The waiter a cycle would come back to
--- @param on string The proposed blocker the walk starts from
--- @return {string} | nil The ids from `on` to `id`, `on` first
local function cycle_path(index: item.Index, id: string,
    on: string): {string} | nil
  local frontier: {{string}} = {{on}}
  local seen: {string: boolean} = {[on] = true}
  for _ = 1, item.MAX_DEPTH do
    local next_frontier: {{string}} = {}
    for _, path in ipairs(frontier) do
      local here = index[path[#path]]
      for _, dep in ipairs(here ~= nil and here.depends_on or {}) do
        local step: {string} = {}
        for _, p in ipairs(path) do step[#step + 1] = p end
        step[#step + 1] = dep
        if dep == id then
          return step
        end
        if not seen[dep] then
          seen[dep] = true
          next_frontier[#next_frontier + 1] = step
        end
      end
    end
    if #next_frontier == 0 then
      return nil
    end
    frontier = next_frontier
  end
  return nil
end

--- The proposed parent's existing chain must reach a root without placing the
--- child above itself. A bounded walk also terminates on already-corrupt cycles.
local function attach_refusal(index: item.Index, id: string, parent: string): string | nil
  if id == parent then return "an item cannot parent itself" end
  local seen: {string: boolean} = {}
  local current = index[parent]
  for _ = 1, item.MAX_DEPTH do
    if current == nil or seen[current.id] then
      return parent:sub(1, 8) .. "'s own parent chain is broken"
    end
    if current.id == id then
      return ("attaching under %s would make a cycle"):format(parent:sub(1, 8))
    end
    if (current.parent or "") == "" then return nil end
    seen[current.id] = true
    current = index[current.parent]
  end
  return parent:sub(1, 8) .. "'s own parent chain is broken"
end
--- Mirror read.role over the frozen item graph for pure replay decisions.
local function role(index: item.Index, it: item.Item): string
  if (it.parent or "") == "" then return "board" end
  if not item.is_review_or_rework(it) then
    for _, candidate in pairs(index) do
      if candidate.parent == it.id and item.is_open(candidate) then return "container" end
    end
  end
  local parent = index[it.parent]
  if parent ~= nil and (parent.parent or "") == "" then return "outcome" end
  return "work"
end
--- Whether filing under `parent` reopens it: a resolved outcome does, because
--- a child under it is explicit evidence against the resolution; a review or
--- rework item never does.
--- @param parent item.Item The proposed parent
--- @param parent_role string Its role, from `role`
--- @return boolean True when the parent's resolution must be cleared
local function reopen(parent: item.Item, parent_role: string): boolean
  return not item.is_review_or_rework(parent) and parent_role == "outcome"
  and (parent.resolution or "") ~= ""
end
--- Why `it` cannot be written, as one line; nil when it is well formed.
--- @param it item.Item The item as the mutation would leave it
--- @return string | nil The joined problems, nil when there are none
local function item_refusal(it: item.Item): string | nil
  local bad = item.problems(it)
  if #bad > 0 then return table.concat(bad, "; ") end
  return nil
end
local record Module
  role: function(item.Index, item.Item): string
  reopen: function(item.Item, string): boolean
  item_refusal: function(item.Item): string | nil
  cycle_path: function(item.Index, string, string): {string} | nil
  attach_refusal: function(item.Index, string, string): string | nil
end
local M: Module = {role = role, reopen = reopen, item_refusal = item_refusal, cycle_path = cycle_path, attach_refusal = attach_refusal}
return M
