--- depend/undepend: declare, and withdraw, the relation that says an
--- item may not START yet. Beside `_work.gitspec` for the same reason
--- that one is separate — it moves the DEFINITION of work rather than
--- its motion — and apart from `_work.gitset`, which moves every other
--- declared field, because the cycle check belongs in ONE place and a
--- general field setter is the wrong place for it.
---
--- `depends_on` lives on the WAITER, so only the waiter's ref moves: a
--- blocker never learns who is waiting on it, and `done` on the blocker
--- frees every waiter with no second write. The relation does not move
--- rank — parentage says where in the queue an item sits, dependency
--- only whether it may start — and a waiter stays workable rather than
--- becoming a container.
---
--- A cycle is refused at the mutation that would close it: the walk
--- runs from the proposed blocker over `depends_on`, breadth-first,
--- bounded by `item.MAX_DEPTH` hops the same way every other walk over
--- the graph is, and refuses when it reaches the waiter.
local gate = require("_work.gitgate")
local item = require("_work.item")
local store = require("_work.store")
local tail = require("_work.tail")

--- The path from `on` back to `id` through `depends_on`, or nil when
--- `on` does not reach `id` at all. Breadth-first from `on`, so the
--- path reported is a shortest one, and bounded by `item.MAX_DEPTH`
--- hops: a board whose dependency chains are already deeper than that
--- is `fsck`'s to report, never a reason to accept a cycle here.
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

--- The handles of `path`, joined the way a rendered chain reads.
--- @param path {string} Item ids
--- @return string The handles, arrow-joined
local function handles(path: {string}): string
  local out: {string} = {}
  for _, id in ipairs(path) do
    out[#out + 1] = tail.handle(id)
  end
  return table.concat(out, " → ")
end

--- The board as both verbs need to see it: the waiter, and every item
--- by id for the cycle walk. One record rather than two return slots,
--- because a fallible return carries the value in slot 1 and the
--- refusal in slot 2 and has nowhere to put a third.
local record Pair
  it: item.Item
  index: item.Index
end

--- Both verbs' shared reading: the board once, indexed, with every
--- refusal that does not depend on which direction the edge moves.
--- @param s store.Store The store
--- @param id string The waiter
--- @param on string The blocker
--- @return Pair | nil The waiter and the index, nil when a refusal stands
--- @return string The refusal, "" when nothing refused
local function both_open(s: store.Store, id: string, on: string):
  Pair | nil, string
  if on == id then
    return nil, "REFUSED: an item cannot depend on itself"
  end
  local all, aerr = store.list(s)
  if all == nil then
    return nil, aerr
  end
  local index = item.by_id(all)
  local it = index[id]
  if it == nil then
    return nil, ("no item %s"):format(id)
  end
  local blocker = index[on]
  if blocker == nil then
    return nil, ("no item %s"):format(on)
  end
  for _, x in ipairs({it, blocker}) do
    if not item.is_open(x) then
      return nil, ("REFUSED: %s is done (%s) — a finished item's "
        .. "dependencies are history, not a repair target"):format(
        x.id:sub(1, 8), x.resolution)
    end
  end
  return {it = it, index = index}, ""
end

--- @param s store.Store The store
--- @param id string The item that may not start yet
--- @param on string The item it waits on
--- @param session string | nil The session making the write
--- @param force boolean | nil Write onto a foreign LIVE claim
--- @param why string | nil Why --force was needed
--- @return integer Exit code
local function cmd_depend(s: store.Store, id: string, on: string,
    session?: string, force?: boolean, why?: string): integer
  local frc, rsn = force or false, why or ""
  local forced = gate.force_refusal(frc, rsn)
  if forced then
    return gate.verdict_line("depend", false, "REFUSED: " .. forced)
  end
  local pair, refusal = both_open(s, id, on)
  if pair == nil then
    return gate.verdict_line("depend", false, refusal)
  end
  local it = pair.it
  for _, dep in ipairs(it.depends_on or {}) do
    if dep == on then
      return gate.verdict_line("depend", true,
        ("%s already depends on %s — nothing written"):format(
          tail.handle(id), tail.handle(on)))
    end
  end
  local cycle = cycle_path(pair.index, id, on)
  if cycle ~= nil then
    return gate.verdict_line("depend", false,
      ("REFUSED: depending on %s would close a cycle: %s"):format(
        tail.handle(on), handles(cycle)))
  end
  local declared: {string} = {}
  for _, dep in ipairs(it.depends_on or {}) do declared[#declared + 1] = dep end
  declared[#declared + 1] = on
  it.depends_on = declared
  local bad = item.problems(it)
  if #bad > 0 then
    return gate.verdict_line("depend", false, table.concat(bad, "; "))
  end
  local ok, err = gate.commit_and_publish(s, it, nil,
    ("depend %s on %s%s"):format(id:sub(1, 8), on:sub(1, 8),
      gate.forced_suffix(frc, rsn)), "depend", nil, session, false, frc, rsn)
  if not ok then
    return gate.verdict_line("depend", false, err)
  end
  if store.is_noop(err) then
    return gate.verdict_line("depend", true, err)
  end
  return gate.verdict_line("depend", true,
    ("%s waits on %s — not pullable until it is done"):format(
      tail.handle(id), tail.handle(on)))
end

--- @param s store.Store The store
--- @param id string The waiter
--- @param on string The dependency to withdraw
--- @param session string | nil The session making the write
--- @param force boolean | nil Write onto a foreign LIVE claim
--- @param why string | nil Why --force was needed
--- @return integer Exit code
local function cmd_undepend(s: store.Store, id: string, on: string,
    session?: string, force?: boolean, why?: string): integer
  local frc, rsn = force or false, why or ""
  local forced = gate.force_refusal(frc, rsn)
  if forced then
    return gate.verdict_line("undepend", false, "REFUSED: " .. forced)
  end
  local pair, refusal = both_open(s, id, on)
  if pair == nil then
    return gate.verdict_line("undepend", false, refusal)
  end
  local it = pair.it
  local kept: {string} = {}
  local found = false
  for _, dep in ipairs(it.depends_on or {}) do
    if dep == on then
      found = true
    else
      kept[#kept + 1] = dep
    end
  end
  if not found then
    return gate.verdict_line("undepend", true,
      ("%s does not depend on %s — nothing written"):format(
        tail.handle(id), tail.handle(on)))
  end
  it.depends_on = kept
  local ok, err = gate.commit_and_publish(s, it, nil,
    ("undepend %s on %s%s"):format(id:sub(1, 8), on:sub(1, 8),
      gate.forced_suffix(frc, rsn)), "undepend", nil, session, false, frc, rsn)
  if not ok then
    return gate.verdict_line("undepend", false, err)
  end
  if store.is_noop(err) then
    return gate.verdict_line("undepend", true, err)
  end
  return gate.verdict_line("undepend", true,
    ("%s no longer waits on %s"):format(tail.handle(id), tail.handle(on)))
end

local record gitdepend
  cmd_depend: function(s: store.Store, id: string, on: string,
  session?: string, force?: boolean, why?: string): integer
  cmd_undepend: function(s: store.Store, id: string, on: string,
  session?: string, force?: boolean, why?: string): integer
end

local M: gitdepend = {
  cmd_depend = cmd_depend,
  cmd_undepend = cmd_undepend,
}

return M
