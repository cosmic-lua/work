--- Cross-item path collisions: which OTHER open items name the same
--- file under their `## Change` heading as a given item does — the
--- fact `gitboard show` and `gitboard next` surface so an orchestrator
--- does not have to `show` every pullable item by hand and compare
--- specs by eye to find two that touch the same file.
---
--- `paths_named` is the pure text extraction, checked against the
--- real tree this process runs from (relative paths resolve against
--- the working directory, which is the repo root for every normal
--- invocation and for the test runner alike) — a token that is not an
--- actual file is not a path, whatever it looks like. `collisions`,
--- `lines`, and `inline` build on it plus a map of already-read spec
--- bodies, the same shape `_work.gitview`'s `read_specs` produces —
--- this module does no store I/O of its own; the `cmd_*` callers own
--- that, per the read-verb convention the rest of `_work` follows.
---
--- `headroom_lines` reuses the same `paths_named` extraction for a
--- second, unrelated question about the same Change section: not
--- whether another item also names a path, but whether the path
--- itself has room left under the 500-line cap `--check lint`
--- enforces. A file already within `WARN_MARGIN` lines of `FILE_CAP`
--- is a warning, never a refusal — the same `--force`-free bar every
--- other line in `overlap.lines` already is — surfaced on `show` so a
--- refiner or builder plans a repacking or split before pulling
--- rather than discovering the tightness live, mid-implementation, the
--- way `wc -l` and `--check lint` otherwise would.
local fs = require("cosmic.fs")
local tail = require("_work.tail")

--- The file-length lint's own ceiling ([D39] in `cosmic-lua/cosmic`:
--- no prose exemption from it) — kept here rather than imported, since
--- no module in this tree computes line counts and the number itself
--- is the one this repo's own `.tl` files are already held to.
local FILE_CAP < const > = 500

--- How close to `FILE_CAP` counts as tight enough to warn about — wide
--- enough that a builder's own addition (the friction this exists to
--- catch ran 12-14 lines) still fits inside the margin most of the
--- time, narrow enough that a file with real room left stays quiet.
local WARN_MARGIN < const > = 20

--- Whether `token` has a path's shape: only path-safe characters, at
--- least one `/`, and an extension on its last segment. Rules out a
--- verb or flag caught in backticks for other reasons (`` `take` ``,
--- `` `--why` ``) and a dotted module name (`` `_work.gitverbs` ``,
--- no `/`), without ruling out a multi-segment path
--- (`docs/decisions/d20-naming-charter.md`).
--- @param token string A backtick-quoted span
--- @return boolean True when it has a path's shape
local function looks_like_path(token: string): boolean
  if token:match("[^%w_%-%./]") then
    return false
  end
  if not token:find("/") then
    return false
  end
  local base = token:match("([^/]+)$")
  return base ~= nil and base:match("%.[%w_%-]+$") ~= nil
end

--- The non-blank lines under `spec_text`'s `## Change` heading (any
--- level, matched case-insensitively), joined — the same
--- heading-scanning `_work.spec.sections` runs for the spec bar,
--- narrowed to the one heading this module reads: a thematic break
--- (`---`) ends the section the way it ends any other.
--- @param spec_text string An item's spec sidecar body
--- @return string The Change section's lines, "" when it has none
local function change_section(spec_text: string): string
  local current: string = nil
  local out = ""
  for line in (spec_text .. "\n"):gmatch("([^\n]*)\n") do
    local text = line:match("^#+%s+(.-)%s*$")
    if text then
      current = text:lower()
    elseif line:match("^%s*%-%-%-+%s*$") then
      current = nil
    elseif current == "change" and line:match("%S") then
      out = out .. line .. "\n"
    end
  end
  return out
end

--- Every backtick-quoted, path-looking token in `spec_text`'s `##
--- Change` section that names a file actually present in the tree —
--- the filter that keeps a plausible-looking token (a stale path from
--- a rewritten plan, a path in prose about a FUTURE file) from
--- reading as a real collision. Deduplicated, first-seen order.
--- @param spec_text string An item's spec sidecar body
--- @return {string} The paths its Change section names
local function paths_named(spec_text: string): {string}
  local change = change_section(spec_text)
  local seen: {string: boolean} = {}
  local out: {string} = {}
  for token in change:gmatch("`([^`\n]+)`") do
    if looks_like_path(token) and not seen[token] and fs.is_present(token) then
      seen[token] = true
      out[#out + 1] = token
    end
  end
  return out
end

--- `path`'s line count the way `wc -l` counts it — newlines, not
--- logical lines — the same measure the file-length lint reads, so a
--- count here never disagrees with what `--check lint` would say.
--- nil when `path` cannot be read: an item's Change section can name a
--- file in another repo entirely (`cosmic-lua/cosmic`, say), and this
--- process's own tree is the only one it can honestly measure.
--- @param path string A path already known to be present (`fs.is_present`)
--- @return integer | nil The newline count, nil when unreadable
local function line_count(path: string): integer | nil
  local text = fs.read(path)
  if text == nil then
    return nil
  end
  local n = 0
  for _ in text:gmatch("\n") do
    n = n + 1
  end
  return n
end

--- One `tight: ...` line per Change-section path already within
--- `WARN_MARGIN` lines of `FILE_CAP`, in `paths_named` order. A path
--- not present in the tree this process runs from is silently skipped
--- (`paths_named` already filters to real paths, and `line_count`
--- would return nil for it either way) — the product tree is checked
--- when it is reachable, and nothing is claimed when it is not.
--- @param body string An item's spec sidecar body
--- @return {string} The lines, possibly empty
local function headroom_lines(body: string): {string}
  local out: {string} = {}
  for _, path in ipairs(paths_named(body)) do
    local n = line_count(path)
    if n ~= nil and FILE_CAP - n <= WARN_MARGIN then
      out[#out + 1] = ("tight: `%s` is %d/%d lines, %d left before the cap —"
        .. " plan a repacking or split before pulling"):format(
        path, n, FILE_CAP, FILE_CAP - n)
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

--- Every OTHER item in `bodies` whose Change-section paths intersect
--- `id`'s, sorted by id (creation order) for a deterministic render.
--- Empty when `id` itself names nothing, without inspecting `bodies`
--- any further.
--- @param id string The item to check
--- @param bodies {string: string} Spec sidecar body by id, open items only
--- @return {Collision} Colliding items, each with its shared paths
local function collisions(id: string, bodies: {string: string}): {Collision}
  local out: {Collision} = {}
  local mine: {string: boolean} = {}
  for _, p in ipairs(paths_named(bodies[id] or "")) do
    mine[p] = true
  end
  if next(mine) == nil then
    return out
  end
  local others: {string} = {}
  for other_id in pairs(bodies) do
    if other_id ~= id then
      others[#others + 1] = other_id
    end
  end
  table.sort(others)
  for _, other_id in ipairs(others) do
    local shared: {string} = {}
    for _, p in ipairs(paths_named(bodies[other_id] or "")) do
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
--- @param bodies {string: string} Spec sidecar body by id, open items only
--- @return {string} The lines, possibly empty
local function lines(id: string, bodies: {string: string}): {string}
  local out: {string} = {}
  for _, c in ipairs(collisions(id, bodies)) do
    out[#out + 1] = ("overlaps: %s on %s"):format(tail.handle(c.id),
      table.concat(c.paths, ", "))
  end
  return out
end

--- The same annotation as `lines`, joined onto one line for `next`'s
--- `or: pull` alternates — "" when nothing collides, so a caller
--- appends it only when it applies.
--- @param id string The item to check
--- @param bodies {string: string} Spec sidecar body by id, open items only
--- @return string The joined annotation, "" when none
local function inline(id: string, bodies: {string: string}): string
  return table.concat(lines(id, bodies), "; ")
end

local record overlap
  type Collision = Collision
  paths_named: function(spec_text: string): {string}
  collisions: function(id: string, bodies: {string: string}): {Collision}
  lines: function(id: string, bodies: {string: string}): {string}
  inline: function(id: string, bodies: {string: string}): string
  headroom_lines: function(body: string): {string}
end

local M: overlap = {
  paths_named = paths_named,
  collisions = collisions,
  lines = lines,
  inline = inline,
  headroom_lines = headroom_lines,
}

return M
