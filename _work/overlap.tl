--- Cross-item path collisions: which OTHER open items declare the
--- same file in their `touches` field as a given item does — the fact
--- `gitboard show` and `gitboard next` surface so an orchestrator does
--- not have to `show` every pullable item by hand and compare their
--- declared lists by eye to find two that touch the same file.
---
--- `present_paths` is the one filter, checked against the real tree
--- this process runs from (relative paths resolve against the working
--- directory, which is the repo root for every normal invocation and
--- for the test runner alike): a declared path that no longer exists
--- is not a collision, and `touches` is advisory, never refused on.
--- `collisions`, `lines`, and `inline` build on it plus a map of
--- declared lists by id, built from the item rows a whole-board read
--- already returned — this module does no store I/O of its own; the
--- `cmd_*` callers own that, per the read-verb convention the rest of
--- `_work` follows.
local fs = require("cosmic.fs")
local tail = require("_work.tail")

--- Every path in `touches` that names a file actually present in the
--- tree — the filter that keeps a declared path that is gone (a stale
--- entry from a rewritten plan, a FUTURE file not yet created) from
--- reading as a real collision. Deduplicated, first-seen order.
--- @param touches {string} An item's declared `touches` list
--- @return {string} The paths of it that are present
local function present_paths(touches: {string}): {string}
  local seen: {string: boolean} = {}
  local out: {string} = {}
  for _, path in ipairs(touches) do
    if not seen[path] and fs.is_present(path) then
      seen[path] = true
      out[#out + 1] = path
    end
  end
  return out
end

--- One colliding item: its id and the paths it shares with the item
--- being checked.
local record Collision
  id: string
  paths: {string}
end

--- Every OTHER item in `touches` whose present declared paths
--- intersect `id`'s, sorted by id (creation order) for a deterministic
--- render. Empty when `id` itself declares nothing present, without
--- inspecting `touches` any further.
--- @param id string The item to check
--- @param touches {string: {string}} Declared `touches` by id, open items only
--- @return {Collision} Colliding items, each with its shared paths
local function collisions(id: string, touches: {string: {string}}): {Collision}
  local out: {Collision} = {}
  local mine: {string: boolean} = {}
  for _, p in ipairs(present_paths(touches[id] or {})) do
    mine[p] = true
  end
  if next(mine) == nil then
    return out
  end
  local others: {string} = {}
  for other_id in pairs(touches) do
    if other_id ~= id then
      others[#others + 1] = other_id
    end
  end
  table.sort(others)
  for _, other_id in ipairs(others) do
    local shared: {string} = {}
    for _, p in ipairs(present_paths(touches[other_id] or {})) do
      if mine[p] then
        shared[#shared + 1] = p
      end
    end
    if #shared > 0 then
      out[#out + 1] = {id = other_id, paths = shared}
    end
  end
  return out
end

--- One `overlaps: <handle> on <path>[, <path>...]` line per colliding
--- item — what `show` prints, an empty list when nothing collides.
--- @param id string The item to check
--- @param touches {string: {string}} Declared `touches` by id, open items only
--- @return {string} The lines, possibly empty
local function lines(id: string, touches: {string: {string}}): {string}
  local out: {string} = {}
  for _, c in ipairs(collisions(id, touches)) do
    out[#out + 1] = ("overlaps: %s on %s"):format(tail.handle(c.id),
      table.concat(c.paths, ", "))
  end
  return out
end

--- The same annotation as `lines`, joined onto one line for `next`'s
--- `or: pull` alternates — "" when nothing collides, so a caller
--- appends it only when it applies.
--- @param id string The item to check
--- @param touches {string: {string}} Declared `touches` by id, open items only
--- @return string The joined annotation, "" when none
local function inline(id: string, touches: {string: {string}}): string
  return table.concat(lines(id, touches), "; ")
end

local record overlap
  type Collision = Collision
  collisions: function(id: string, touches: {string: {string}}): {Collision}
  lines: function(id: string, touches: {string: {string}}): {string}
  inline: function(id: string, touches: {string: {string}}): string
end

local M: overlap = {
  collisions = collisions,
  lines = lines,
  inline = inline,
}

return M
