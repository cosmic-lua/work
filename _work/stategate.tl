--- Revalidate format-6 whole-board gates after a disjoint writer moved state.
--- Dependency checks run before this callback; these checks cover facts whose
--- membership can grow at a previously absent path.
local boardread = require("_work.boardread")
local flow = require("_work.flow")
local item = require("_work.item")
local projection = require("_work.stateplan_git")
local tx = require("_work.statetransaction")

local function changed_item_ids(t: tx.Transition): {string: boolean}
  local out: {string: boolean} = {}
  for _, change in ipairs(t.changes) do
    local id = change.path:match("^items/([^/]+)/")
    if id ~= nil then out[id] = true end
  end
  return out
end

local function parent_refusal(items: {item.Item}, changed: {string: boolean}): string | nil
  local by_id = item.by_id(items)
  for _, it in ipairs(items) do
    if changed[it.id] then
      local seen: {string: boolean} = {[it.id] = true}
      local parent, depth = it.parent or "", 0
      while parent ~= "" do
        if seen[parent] then return "attach gate: parent cycle at " .. it.id end
        seen[parent], depth = true, depth + 1
        if depth > item.MAX_DEPTH then return "attach gate: parent chain is too deep at " .. it.id end
        local p = by_id[parent]
        if p == nil then return "attach gate: missing parent " .. parent end
        parent = p.parent or ""
      end
    end
  end
  return nil
end

local function dependency_refusal(items: {item.Item}, changed: {string: boolean}): string | nil
  local by_id = item.by_id(items)
  for _, start in ipairs(items) do
    if changed[start.id] then
      local frontier: {string} = {}; for _, d in ipairs(start.depends_on or {}) do frontier[#frontier + 1] = d end
      local seen: {string: boolean} = {}
      for _ = 1, item.MAX_DEPTH do
        local nexts: {string} = {}
        for _, id in ipairs(frontier) do
          if id == start.id then return "depend gate: dependency cycle at " .. start.id end
          if not seen[id] then
            seen[id] = true
            local found = by_id[id]
            if found ~= nil then for _, d in ipairs(found.depends_on or {}) do nexts[#nexts + 1] = d end end
          end
        end
        frontier = nexts
        if #frontier == 0 then break end
      end
    end
  end
  return nil
end

local function rank_refusal(t: tx.Transition, items: {item.Item}): string | nil
  local by_id = item.by_id(items)
  for _, change in ipairs(t.changes) do
    local parent = change.path:match("^items/([^/]+)/order$")
    if parent ~= nil then
      local p = by_id[parent]
      if p == nil then return "rank gate: missing parent " .. parent end
      for _, id in ipairs(p.order or {}) do
        local child = by_id[id]
        if child ~= nil and (child.parent or "") ~= parent then
          return "rank gate: " .. id .. " is no longer a sibling"
        end
      end
    end
  end
  return nil
end

local function doing_count(items: {item.Item}): integer
  local n = 0
  for _, it in ipairs(items) do
    if item.is_open(it) and ((it.claim or "") ~= "" or (it.pr or 0) ~= 0) then n = n + 1 end
  end
  return n
end

local function lane_refusal(before: {item.Item}, after: {item.Item},
    changed: {string: boolean}): string | nil
  local old = item.by_id(before)
  for _, added in ipairs(after) do
    if changed[added.id] and old[added.id] == nil
    and flow.is_lane_repair(added.parent or "", added.title or "") then
      for _, present in ipairs(before) do
        if item.is_open(present) and present.parent == added.parent
        and present.title == added.title then return "lane gate: repair already exists: " .. present.id end
      end
    end
  end
  return nil
end

local function done_refusal(before: {item.Item}, after: {item.Item},
    changed: {string: boolean}): string | nil
  local old, now = item.by_id(before), item.by_id(after)
  for id in pairs(changed) do
    local was, ended = old[id], now[id]
    if was ~= nil and ended ~= nil and item.is_open(was) and not item.is_open(ended) then
      for _, child in ipairs(before) do
        if child.parent == id and item.is_open(child) then
          return "done gate: open child remains: " .. child.id
        end
      end
    end
  end
  return nil
end

local function check(root: string, head: string, transition: tx.Transition): boolean, string
  local known = transition.gate == "take" or transition.gate == "doing-bound"
  or transition.gate == "new" or transition.gate == "lane-mint"
  or transition.gate == "depend" or transition.gate == "attach"
  or transition.gate == "rank" or transition.gate == "done"
  if not known then return false, "unknown bounded gate: " .. transition.gate end
  local before, berr = boardread.list(root, head)
  if before == nil then return false, berr end
  if transition.gate == "take" or transition.gate == "doing-bound" then
    if doing_count(before.items) >= flow.DOING_LIMIT then return false, "doing bound reached" end
    return true, ""
  end
  local tree, terr = projection.apply(root, head, transition.changes)
  if tree == nil then return false, terr end
  local after, aerr = boardread.list(root, tree)
  if after == nil then return false, aerr end
  local changed = changed_item_ids(transition)
  local refusal: string | nil
  if transition.gate == "new" or transition.gate == "lane-mint" then
    refusal = lane_refusal(before.items, after.items, changed)
  elseif transition.gate == "depend" then refusal = dependency_refusal(after.items, changed)
  elseif transition.gate == "attach" then refusal = parent_refusal(after.items, changed)
  elseif transition.gate == "rank" then refusal = rank_refusal(transition, after.items)
  elseif transition.gate == "done" then refusal = done_refusal(before.items, after.items, changed) end
  return refusal == nil, refusal or ""
end

local record stategate
  check: function(string, string, tx.Transition): boolean, string
end
local M: stategate = {check = check}
return M
