--- Migration diagnostics retain unresolved evidence; they never guess another
--- repository's commit identity or silently turn a legacy digest into a mark.
local boardtree = require("_work.boardtree")
local gitobj = require("_work.gitobj")
local itemtree = require("_work.itemtree")

local record Report
  fields: {string: string}
  results: {string: string}
  count: integer
end

--- @param root string Repository holding the replayed candidate
--- @param head string Candidate commit id
--- @param marks {string:string} Exact old-board-commit to replayed-commit map
--- @return Report | nil Every unresolved evidence field and result item
--- @return string Read error
local function inspect(root: string, head: string, marks: {string: string}): Report | nil, string
  local entries, err = boardtree.snapshot_entries(root, head)
  if entries == nil then return nil, err end
  local queries: {string} = {}
  for _, entry in ipairs(entries) do
    if entry.path:match("^items/[^/]+/meta$") then queries[#queries + 1] = entry.sha end
  end
  local blobs, berr = gitobj.cat_file_batch(root, queries)
  if blobs == nil then return nil, berr end
  local mapped: {string: boolean} = {}
  for _, sha in pairs(marks) do mapped[sha] = true end
  local out: Report = {fields = {}, results = {}, count = 0}
  for _, entry in ipairs(entries) do
    local id = entry.path:match("^items/([^/]+)/meta$")
    if id ~= nil then
      if blobs[entry.sha] == nil then return nil, "missing migrated meta for " .. id end
      local meta = itemtree.parse_meta(blobs[entry.sha].content)
      for _, key in ipairs({"result", "verdict_head", "landed_head"}) do
        local value = meta[key] or ""
        if value ~= "" and marks[value] == nil and not mapped[value] then
          out.fields[id .. ":" .. key], out.count = value, out.count + 1
          if key == "result" then out.results[id] = value end
        end
      end
    end
  end
  return out, ""
end

local record Diagnostics
  type Report = Report
  inspect: function(string, string, {string: string}): Report | nil, string
end
local M: Diagnostics = {inspect = inspect}
return M
