--- The two `depends_on` findings `gitboard fsck` reports over the
--- whole board — whole-board questions no verb asks. Beside
--- `_work.gitfsck_claimbatch`, split out for the same reason: the
--- cache audit sits against the file cap.
---
--- `undeclared_blockers`: an open item whose Change blob says it is
--- blocked on another item — a blocking phrase (`blocked on`,
--- `blocked by`, `depends on`, `waits on`, `waiting on`) followed by
--- the `«handle»` spelling `_work.tail` renders — where that item is
--- not in its `depends_on`. A dependency is a relation, never
--- inferred from prose, so the finding names the prose that still
--- wants one and the `gitboard depend` that declares it. Only the
--- blocking phrasings count: a spec cites items for many reasons —
--- provenance, a sibling's contrast, a duplicate — and a bare handle
--- is not a claim of blocking. A resolved item is not asked: nothing
--- reads its `depends_on` any more.
---
--- `cycles`: a `depends_on` cycle, walked breadth-first and bounded
--- by `item.MAX_DEPTH` hops — the same bound `gitboard depend`'s
--- refusal uses — reported here rather than refused, because the
--- refs may already carry one from a hand edit and an audit reports
--- what is. One line per cycle, not one per member.
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local tail = require("_work.tail")

--- The phrasings that make a `«handle»` after them a claim of
--- blocking, matched case-insensitively.
local BLOCKING_PHRASES < const >: {string} = {
  "blocked on", "blocked by", "depends on", "waits on", "waiting on",
}

--- Every item's id by its lower-cased 8-character tail — the part a
--- rendered handle carries, collision-free across the live board.
--- @param all {item.Item} Every item
--- @return {string: string} Lower-cased tail -> id
local function ids_by_tail(all: {item.Item}): {string: string}
  local out: {string: string} = {}
  for _, it in ipairs(all) do
    out[it.id:sub(20):lower()] = it.id
  end
  return out
end

--- The tails `change` names as blocking, lower-cased with the
--- divider dropped, deduplicated in first-seen order.
--- @param change string The Change blob
--- @return {string} Bare lower-cased tails
local function blocking_tails(change: string): {string}
  local low = change:lower()
  local seen: {string: boolean} = {}
  local out: {string} = {}
  for _, phrase in ipairs(BLOCKING_PHRASES) do
    for wrapped in low:gmatch(phrase .. "%s*«(%w%w%w%w[%-_]?%w%w%w%w)»") do
      local bare = (wrapped:gsub("[%-_]", ""))
      if not seen[bare] then
        seen[bare] = true
        out[#out + 1] = bare
      end
    end
  end
  return out
end

--- One line per open item whose Change names an item as blocking
--- that its `depends_on` does not declare, naming every such item
--- and the `depend` that declares it. A tail that resolves to no item
--- on the board is prose about something else and is left alone.
--- @param all {item.Item} Every item
--- @param specs {string: itemtree.Spec} Each item's prose, by id
--- @return {string} The findings, possibly empty
local function undeclared_blockers(all: {item.Item},
    specs: {string: itemtree.Spec}): {string}
  local ids = ids_by_tail(all)
  local out: {string} = {}
  for _, it in ipairs(all) do
    if item.is_open(it) then
      local declared: {string: boolean} = {}
      for _, dep in ipairs(it.depends_on or {}) do
        declared[dep] = true
      end
      local sp = specs[it.id]
      local missing: {string} = {}
      local repairs: {string} = {}
      for _, bare in ipairs(blocking_tails(sp ~= nil and sp.change or "")) do
        local blocker = ids[bare]
        if blocker ~= nil and blocker ~= it.id and not declared[blocker] then
          missing[#missing + 1] = tail.handle(blocker)
          repairs[#repairs + 1] = ("`gitboard depend %s %s`"):format(
            it.id:sub(1, 8), blocker:sub(1, 8))
        end
      end
      if #missing > 0 then
        out[#out + 1] = ("%s: Change names %s as blocking but depends_on does "
          .. "not declare it — %s"):format(tail.handle(it.id),
          table.concat(missing, ", "), table.concat(repairs, "; "))
      end
    end
  end
  return out
end

--- The shortest `depends_on` path from `id` back to itself, `id` at
--- both ends, or nil when none closes within `item.MAX_DEPTH` hops —
--- breadth-first, the walk `gitboard depend` refuses on.
--- @param index item.Index Every item by id
--- @param id string The item to walk from
--- @return {string} | nil The cycle's ids, `id` first and last
local function cycle_from(index: item.Index, id: string): {string} | nil
  local frontier: {{string}} = {{id}}
  local seen: {string: boolean} = {[id] = true}
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

--- One line per `depends_on` cycle on the board, each member's
--- handle arrow-joined and the first repeated at the end, reported
--- once however many members it has.
--- @param all {item.Item} Every item
--- @return {string} The findings, possibly empty
local function cycles(all: {item.Item}): {string}
  local index = item.by_id(all)
  local reported: {string: boolean} = {}
  local out: {string} = {}
  for _, it in ipairs(all) do
    if #(it.depends_on or {}) > 0 then
      local cycle = cycle_from(index, it.id)
      if cycle ~= nil then
        local members: {string} = {}
        for k = 1, #cycle - 1 do members[k] = cycle[k] end
        table.sort(members)
        local key = table.concat(members, " ")
        if not reported[key] then
          reported[key] = true
          local handles: {string} = {}
          for k, id in ipairs(cycle) do handles[k] = tail.handle(id) end
          out[#out + 1] = ("cycle: depends_on closes on itself: %s — "
            .. "`gitboard undepend` one edge"):format(
            table.concat(handles, " → "))
        end
      end
    end
  end
  return out
end

--- Both findings, blockers first, in board order.
--- @param all {item.Item} Every item
--- @param specs {string: itemtree.Spec} Each item's prose, by id
--- @return {string} The findings, possibly empty
local function problems(all: {item.Item},
    specs: {string: itemtree.Spec}): {string}
  local out = undeclared_blockers(all, specs)
  for _, p in ipairs(cycles(all)) do
    out[#out + 1] = p
  end
  return out
end

local record gitfsck_depends
  blocking_tails: function(change: string): {string}
  undeclared_blockers: function(all: {item.Item},
  specs: {string: itemtree.Spec}): {string}
  cycles: function(all: {item.Item}): {string}
  problems: function(all: {item.Item},
  specs: {string: itemtree.Spec}): {string}
end

local M: gitfsck_depends = {
  blocking_tails = blocking_tails,
  undeclared_blockers = undeclared_blockers,
  cycles = cycles,
  problems = problems,
}

return M
