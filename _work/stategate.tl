--- Revalidate format-6 whole-board gates after a disjoint writer moved state.
--- Dependency checks run before this callback; these checks cover facts whose
--- membership can grow at a previously absent path.
local graphguards = require("_work.graphguards")
local boardread = require("_work.boardread")
local flow = require("_work.flow")
local item = require("_work.item")
local projection = require("_work.stateplan_git")
local tx = require("_work.statetransaction")

--- Every item id this transition writes a path under — the set a re-run gate
--- judges, rather than the whole board it reads to judge them.
--- @param t tx.Transition The frozen transition
--- @return {string: boolean} Item ids present as keys
local function changed_item_ids(t: tx.Transition): {string: boolean}
  local out: {string: boolean} = {}
  for _, change in ipairs(t.changes) do
    local id = change.path:match("^items/([^/]+)/")
    if id ~= nil then out[id] = true end
  end
  return out
end

--- `attach`'s own gate re-run against the fetched head: only an edge this
--- transition actually MOVED is re-judged, through the same
--- `_work.graphguards` predicates the verb used, so a cycle, a broken chain, a
--- newly invalid item, or a parent that now needs reopening refuses here for
--- the same reason it would have refused at the verb.
--- @param before {item.Item} The board at the fetched head
--- @param items {item.Item} That board with this transition applied
--- @param changed {string: boolean} The ids this transition writes
--- @return string | nil The refusal, nil when the edge still holds
local function parent_refusal(before: {item.Item}, items: {item.Item}, changed: {string: boolean}): string | nil
  local index, old = item.by_id(items), item.by_id(before)
  for id in pairs(changed) do
    local it = index[id]
    if it ~= nil and (old[id] == nil or old[id].parent ~= it.parent) then
      local refusal = graphguards.attach_refusal(index, id, it.parent or "")
      if refusal ~= nil then return refusal end
      local bad = graphguards.item_refusal(it)
      if bad ~= nil then return bad end
      local parent_before, parent_after = old[it.parent], index[it.parent]
      if parent_before ~= nil and parent_after ~= nil
      and graphguards.reopen(parent_before, graphguards.role(old, parent_before))
      and (parent_after.resolution or "") ~= "" then
        return "attach gate: parent must be reopened: " .. parent_after.id
      end
    end
  end
  return nil
end
--- `depend`'s own gate re-run against the fetched head: for every dependency
--- this transition ADDS, the shared cycle walk runs again over the board that
--- landed meanwhile, which is how an edit racing onto the cycle path is
--- refused rather than fenced.
--- @param before {item.Item} The board at the fetched head
--- @param items {item.Item} That board with this transition applied
--- @param changed {string: boolean} The ids this transition writes
--- @return string | nil The refusal, nil when no added edge closes a cycle
local function dependency_refusal(before: {item.Item}, items: {item.Item}, changed: {string: boolean}): string | nil
  local index, old = item.by_id(items), item.by_id(before)
  for id in pairs(changed) do
    local it = index[id]
    if it ~= nil then
      local previous: {string: boolean} = {}
      for _, on in ipairs(old[id] ~= nil and old[id].depends_on or {}) do previous[on] = true end
      for _, on in ipairs(it.depends_on or {}) do
        if not previous[on] and (on == id or graphguards.cycle_path(index, id, on) ~= nil) then
          return "depend gate: dependency cycle at " .. id
        end
      end
    end
  end
  return nil
end

--- Match indexddl.workable/state, including commit-only and research handovers.
local function doing_count(items: {item.Item}): integer
  local roots: {string: boolean} = {}
  local parents: {string: boolean} = {}
  for _, it in ipairs(items) do
    if (it.parent or "") == "" then roots[it.id] = true end
    if item.is_open(it) and (it.parent or "") ~= "" then parents[it.parent] = true end
  end
  local n = 0
  for _, it in ipairs(items) do
    if item.is_open(it) and (it.parent or "") ~= "" and not roots[it.parent]
    and not parents[it.id] and ((it.claim or "") ~= "" or (it.pr or 0) ~= 0
      or (it.handover_head or "") ~= "" or (it.result or "") ~= "") then n = n + 1 end
  end
  return n
end

--- The lane mint's gate re-run: a repair item for a lane that already has an
--- open one is refused, which is what the mint read the whole board to decide.
--- @param before {item.Item} The board at the fetched head
--- @param after {item.Item} That board with this transition applied
--- @param changed {string: boolean} The ids this transition writes
--- @return string | nil The refusal naming the existing repair, nil otherwise
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

--- Re-run a BOUNDED mutation's own gate against the head it is about to land
--- on. Publication calls this only after every fenced path matched, so this is
--- the whole of what protects a decision made from reading beyond the items
--- written. An unrecognised gate name refuses: a bounded transition whose gate
--- this build cannot re-run must not be published on trust.
--- @param root string The repository holding `head`
--- @param head string The fetched board head this transition would land on
--- @param transition tx.Transition The frozen transition and its gate name
--- @return boolean True when the gate passes again
--- @return string The gate's own refusal
local function check(root: string, head: string, transition: tx.Transition): boolean, string
  local known = transition.gate == "take" or transition.gate == "doing-bound"
  or transition.gate == "new" or transition.gate == "lane-mint"
  or transition.gate == "depend" or transition.gate == "attach"
  if not known then return false, "unknown bounded gate: " .. transition.gate end
  local before, berr = boardread.list(root, head)
  if before == nil then return false, berr end
  local tree, terr = projection.apply(root, head, transition.changes)
  if tree == nil then return false, terr end
  local after, aerr = boardread.list(root, tree)
  if after == nil then return false, aerr end
  if transition.gate == "take" or transition.gate == "doing-bound" then
    local previous, projected = doing_count(before.items), doing_count(after.items)
    if projected > flow.DOING_LIMIT and projected > previous then
      return false, "doing bound reached"
    end
    return true, ""
  end
  local changed = changed_item_ids(transition)
  local refusal: string | nil
  if transition.gate == "new" or transition.gate == "lane-mint" then
    refusal = lane_refusal(before.items, after.items, changed)
  elseif transition.gate == "depend" then refusal = dependency_refusal(before.items, after.items, changed)
  elseif transition.gate == "attach" then refusal = parent_refusal(before.items, after.items, changed) end
  return refusal == nil, refusal or ""
end

local record stategate
  check: function(string, string, tx.Transition): boolean, string
end
local M: stategate = {check = check}
return M
