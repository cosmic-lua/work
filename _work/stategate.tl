--- Revalidate format-6 whole-board gates after a disjoint writer moved state.
--- Dependency checks run before this callback; these checks cover facts whose
--- membership can grow at a previously absent path.
local graphguards = require("_work.graphguards")
local boardread = require("_work.boardread")
local boardindex = require("_work.index")
local flow = require("_work.flow")
local gitready = require("_work.gitready")
local item = require("_work.item")
local read = require("_work.read")
local spec = require("_work.spec")
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

local function changed_claim_ids(t: tx.Transition): {string: boolean}
  local out: {string: boolean} = {}
  for _, change in ipairs(t.changes) do
    local id = change.path:match("^claims/([^/]+)$")
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
      local previous_parent = old[id] ~= nil and old[id].parent or ""
      if previous_parent ~= "" and previous_parent ~= (it.parent or "") then
        local parent_now, parent_projected = old[previous_parent], index[previous_parent]
        if parent_now ~= nil and parent_projected ~= nil then
          local named_now, named_after = false, false
          for _, child in ipairs(parent_now.order or {}) do
            if child == id then named_now = true end
          end
          for _, child in ipairs(parent_projected.order or {}) do
            if child == id then named_after = true end
          end
          if named_now and named_after then
            return "attach gate: old parent still ranks moved child: " .. id
          end
        end
      end
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

--- A verified outcome depends on no open child remaining. A child can appear
--- at a previously absent path, so the bounded `done` transition rechecks the
--- membership query against the fetched head.
local function done_refusal(before: {item.Item}, items: {item.Item},
    changed: {string: boolean}): string | nil
  local old, index = item.by_id(before), item.by_id(items)
  for id in pairs(changed) do
    local previous, projected = old[id], index[id]
    if previous ~= nil and projected ~= nil and item.is_open(previous)
    and projected.resolution == "completed" then
      for _, child in ipairs(items) do
        if child.parent == id and item.is_open(child) then
          return ("done gate: %s has an open child (%s) left"):format(
            id:sub(1, 8), child.id:sub(1, 8))
        end
      end
    end
  end
  return nil
end

local function ranked(index: item.Index, it: item.Item): boolean
  local current = it
  for _ = 1, item.MAX_DEPTH do
    local parent = index[current.parent or ""]
    if parent == nil then return false end
    if (parent.parent or "") == "" then
      for _, id in ipairs(parent.order or {}) do
        if id == current.id then return true end
      end
      return false
    end
    current = parent
  end
  return false
end

--- A new acquisition rechecks the readiness facts that live outside the
--- target's own fenced item path: graph membership, outcome rank, and blocker
--- state. Spec/access are checked too so this remains the same gate as take.
local function take_refusal(before: boardread.View, after: boardread.View,
    changed: {string: boolean}): string | nil
  local index = item.by_id(after.items)
  for id in pairs(changed) do
    local old_claim, new_claim = before.claims_by_id[id], after.claims_by_id[id]
    if new_claim ~= nil and (old_claim == nil or old_claim.id ~= new_claim.id) then
      local it = index[id]
      if it == nil then return "take gate: no item " .. id end
      local role = graphguards.role(index, it)
      if role ~= "work" then
        return ("take gate: %s is a %s, not workable"):format(id:sub(1, 8), role)
      end
      if not ranked(index, it) then return "take gate: outcome is unranked: " .. id end
      for _, dependency in ipairs(it.depends_on or {}) do
        local blocker = index[dependency]
        if blocker == nil or item.is_open(blocker) then
          return "take gate: unresolved dependency: " .. dependency
        end
      end
      local prose = after.specs_by_id[id]
      if #flow.ready_gaps(prose) > 0 then return "take gate: spec is not ready: " .. id end
      if #gitready.undeclared_repos(it, spec.document(prose)) > 0 then
        return "take gate: spec has undeclared read access: " .. id
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
        if not previous[on] then
          local blocker = index[on]
          if not item.is_open(it) then return "depend gate: waiter is done: " .. id end
          if blocker == nil or not item.is_open(blocker) then
            return "depend gate: blocker is done or absent: " .. on
          end
          if on == id or graphguards.cycle_path(index, id, on) ~= nil then
            return "depend gate: dependency cycle at " .. id
          end
        end
      end
    end
  end
  return nil
end

--- Reuse the ordinary read model for a candidate's complete projected workload.
local function doing_count(items: {item.Item}): integer | nil, string
  local projected, err = boardindex.open(items)
  if projected == nil then return nil, err end
  if #projected.load_problems > 0 then
    local _closed, _cerr = boardindex.close(projected)
    return nil, table.concat(projected.load_problems, "; ")
  end
  local count, cerr = read.doing_count(projected)
  local closed, close_err = boardindex.close(projected)
  if not closed then return nil, close_err end
  return count, cerr
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
  or transition.gate == "rank" or transition.gate == "done"
  if not known then return false, "unknown bounded gate: " .. transition.gate end
  local before, berr = boardread.list(root, head)
  if before == nil then return false, berr end
  local tree, terr = projection.apply(root, head, transition.changes)
  if tree == nil then return false, terr end
  local after, aerr = boardread.list(root, tree)
  if after == nil then return false, aerr end
  if transition.gate == "take" or transition.gate == "doing-bound" then
    local previous, perr = doing_count(before.items)
    if previous == nil then return false, perr end
    local projected, perr2 = doing_count(after.items)
    if projected == nil then return false, perr2 end
    if projected > flow.DOING_LIMIT and projected > previous then
      return false, "doing bound reached"
    end
    local refusal = take_refusal(before, after, changed_claim_ids(transition))
    if refusal ~= nil then return false, refusal end
    return true, ""
  end
  local changed = changed_item_ids(transition)
  local refusal: string | nil
  if transition.gate == "new" or transition.gate == "lane-mint" then
    refusal = lane_refusal(before.items, after.items, changed)
  elseif transition.gate == "depend" then refusal = dependency_refusal(before.items, after.items, changed)
  elseif transition.gate == "attach" then refusal = parent_refusal(before.items, after.items, changed)
  elseif transition.gate == "done" then refusal = done_refusal(before.items, after.items, changed) end
  return refusal == nil, refusal or ""
end

local record stategate
  check: function(string, string, tx.Transition): boolean, string
end
local M: stategate = {check = check}
return M
