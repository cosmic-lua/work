--- Read a caller-named set of ids from one canonical native snapshot.
local gitread = require("_work.gitread")

local type Loaded = gitread.Loaded

--- Missing native item paths are absent from the result.
--- @param root string The repository root
--- @param ids {string} Item ids to read, in any order
--- @return {string: Loaded} | nil Loaded items by id, only those found
--- @return string Error message: a hard failure reading git objects
local function load_many(root: string, ids: {string}): {string: Loaded} | nil, string
  local out: {string: Loaded} = {}
  if #ids == 0 then
    return out
  end
  local board, berr = gitread.list(root)
  if board == nil then return nil, berr end
  local wanted: {string: boolean} = {}
  for _, id in ipairs(ids) do wanted[id] = true end
  for _, it in ipairs(board.items) do
    if wanted[it.id] then
      out[it.id] = {it = it, ref = "refs/heads/state", sha = board.shas_by_id[it.id] or board.native_view.head}
    end
  end
  return out, ""
end

local record gitreadmany
  load_many: function(root: string, ids: {string}): {string: Loaded} | nil, string
end

local M: gitreadmany = {
  load_many = load_many,
}

return M
