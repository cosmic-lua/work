--- Native spec blobs from exact published board commits.
local gitobj = require("_work.gitobj")
local itemtree = require("_work.itemtree")
local function read_specs(root: string, shas_by_id: {string: string},
    ids: {string}, _native_mode?: boolean): {string: itemtree.Spec}
  local native: {string: itemtree.Spec} = {}
  local queries: {string} = {}
  for _, id in ipairs(ids) do
    local sha = shas_by_id[id]
    native[id] = {change = "", non_goals = ""}
    if sha ~= nil then
      local prefix = sha .. ":items/" .. id .. "/spec/"
      queries[#queries + 1], queries[#queries + 2] = prefix .. "change.md", prefix .. "non-goals.md"
      queries[#queries + 1] = sha .. ":items/" .. id .. "/meta"
    end
  end
  local batch, err = gitobj.cat_file_batch(root, queries)
  -- throws: a native prose read must not answer "" for an unread board
  if batch == nil then error(err, 0) end
  do
    for _, id in ipairs(ids) do
      local sha = shas_by_id[id]
      if sha ~= nil then
        local meta = batch[sha .. ":items/" .. id .. "/meta"]
        if meta == nil or meta.otype ~= "blob" then
          -- throws: prose without `meta` is a corrupt item, not an empty spec
          error("native item " .. id .. " has no readable meta at " .. sha, 0)
        end
        local prefix = sha .. ":items/" .. id .. "/spec/"
        local change, non_goals = batch[prefix .. "change.md"], batch[prefix .. "non-goals.md"]
        if change ~= nil then native[id].change = change.content end
        if non_goals ~= nil then native[id].non_goals = non_goals.content end
      end
    end
  end
  return native
end
return {read_specs = read_specs}
