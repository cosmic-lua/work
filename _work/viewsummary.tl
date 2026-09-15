--- Board rollups by repository, for `show --summary`.
---
--- The board's read verbs render rows; a caller asking what the queue
--- looks like rather than what is at its head has to count them. This
--- turns one state's items into one line per repository, so the shape
--- of the board is a read rather than an aggregation.

local item = require("_work.item")

local NO_REPO = "(no repo)"

local record Group
  repo: string
  count: integer
  pullable: integer
end

--- Group one state's items by their `repo` field.
---
--- Ordering is by count descending, then repository name ascending, so
--- the rollup is stable across runs and reads largest-first. Items with
--- no repository set group under a literal placeholder that sorts last
--- whatever its count: it names a gap in the board rather than a place
--- work lands, and mixing it into the ranking would hide that.
--- @param items {item.Item} The state's items
--- @param pullable {string: boolean} | nil Pullable ids, todo only
--- @return {Group} One entry per distinct repository
local function group(items: {item.Item}, pullable: {string: boolean} | nil): {Group}
  local counts: {string: integer} = {}
  local pulls: {string: integer} = {}
  local names: {string} = {}
  for _, it in ipairs(items) do
    local repo = it.repo ~= "" and it.repo or NO_REPO
    if counts[repo] == nil then
      counts[repo] = 0
      pulls[repo] = 0
      names[#names + 1] = repo
    end
    counts[repo] = counts[repo] + 1
    if pullable ~= nil and pullable[it.id] then
      pulls[repo] = pulls[repo] + 1
    end
  end
  table.sort(names, function(a: string, b: string): boolean
      if a == NO_REPO then return false end
      if b == NO_REPO then return true end
      if counts[a] ~= counts[b] then return counts[a] > counts[b] end
      return a < b
    end)
  local out: {Group} = {}
  for _, repo in ipairs(names) do
    out[#out + 1] = {repo = repo, count = counts[repo], pullable = pulls[repo]}
  end
  return out
end

--- Render one state's rollup as indented lines.
---
--- The repository column is padded to the widest name in this rollup
--- alone, so each state's block aligns without the caller measuring
--- across states. A nil `pullable` omits the parenthesised count
--- entirely, which is what every state but todo wants.
--- @param items {item.Item} The state's items
--- @param pullable {string: boolean} | nil Pullable ids, todo only
--- @return {string} One line per repository, in rollup order
local function lines(items: {item.Item}, pullable: {string: boolean} | nil): {string}
  local groups = group(items, pullable)
  local width = 0
  for _, g in ipairs(groups) do
    if #g.repo > width then width = #g.repo end
  end
  local out: {string} = {}
  for _, g in ipairs(groups) do
    local row = ("  %-" .. tostring(width) .. "s %4d"):format(g.repo, g.count)
    if pullable ~= nil then
      row = row .. (" (%d pullable)"):format(g.pullable)
    end
    out[#out + 1] = row
  end
  return out
end

--- Append one state's rollup to a report under construction.
---
--- The caller holds the line buffer every other row in the report is
--- written to, so the rollup appends into it rather than returning a
--- list the caller has to splice: three call sites, one line each.
--- @param out {string} The report being built, appended in place
--- @param items {item.Item} The state's items
--- @param pullable {string: boolean} | nil Pullable ids, todo only
local function emit(out: {string}, items: {item.Item},
    pullable: {string: boolean} | nil)
  for _, line in ipairs(lines(items, pullable)) do out[#out + 1] = line end
end

local record Module
  type Group = Group
  NO_REPO: string
  group: function({item.Item}, {string: boolean} | nil): {Group}
  lines: function({item.Item}, {string: boolean} | nil): {string}
  emit: function({string}, {item.Item}, {string: boolean} | nil)
end

local M: Module = {NO_REPO = NO_REPO, group = group, lines = lines, emit = emit}
return M
