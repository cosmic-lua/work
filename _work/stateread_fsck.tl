--- Native fsck audits canonical item subtrees and claims without mutating Git.
local boardread = require("_work.boardread")
local boardtree = require("_work.boardtree")
local gitobj = require("_work.gitobj")
local ksuid = require("_work.ksuid")

local function problems(root: string, head: string): {string}
  local view, err = boardread.list(root, head)
  if view == nil then return {err} end
  local out: {string} = {}
  local batch, berr = gitobj.cat_file_batch(root, {head .. ":format"})
  if batch == nil then out[#out + 1] = berr
  else
    local marker = batch[head .. ":format"]
    if marker == nil or marker.content ~= "6\n" then
      out[#out + 1] = "state: expected canonical format 6 blob"
    end
  end
  for id in pairs(view.claims_by_id) do
    if view.items_by_id[id] == nil then out[#out + 1] = "claims/" .. id .. ": item is absent" end
  end
  for _, it in ipairs(view.items) do
    if not ksuid.is_id(it.id) then out[#out + 1] = "items/" .. it.id .. ": invalid item id" end
    local rebuilt, rerr = boardtree.rebuild_item(root, it, view.specs_by_id[it.id],
      view.logs_by_id[it.id], view.item_tree_by_id[it.id])
    if rebuilt == nil then out[#out + 1] = "items/" .. it.id .. ": " .. rerr
    elseif rebuilt ~= view.item_tree_by_id[it.id] then
      out[#out + 1] = "items/" .. it.id .. ": canonical form drifted"
    end
  end
  table.sort(out)
  return out
end
return {problems = problems}
