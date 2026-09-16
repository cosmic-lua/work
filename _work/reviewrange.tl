--- Freeze a local product review's target and prove its unique merge base.
local child = require("cosmic.child")
local item = require("_work.item")
local repository_map = require("_work.repository_map")
local gitworktree = require("_work.gitworktree")

local function resolve(board: string, it: item.Item): string | nil, string
  local head = it.handover_head or ""
  local root, err = repository_map.resolve(board, it.repo or "", "")
  local base = gitworktree.default_base(it.repo or "", it.base or "", root or "")
  local function refuse(reason: string): string
    return ("review base %s and handover %s: %s"):format(base, head, reason)
  end
  if root == nil then return nil, refuse(err) end
  local target = child.run({"git", "rev-parse", "--verify", "--end-of-options", base .. "^{commit}"}, {cwd = root})
  if target == nil or not target.ok then return nil, refuse("base ref is missing locally") end
  local handover = child.run({"git", "rev-parse", "--verify", "--end-of-options", head .. "^{commit}"}, {cwd = root})
  if handover == nil or not handover.ok then return nil, refuse("handover is missing locally") end
  local target_sha = target.stdout:gsub("%s+$", "")
  local head_sha = handover.stdout:gsub("%s+$", "")
  local merged = child.run({"git", "merge-base", "--all", target_sha, head_sha}, {cwd = root})
  if merged == nil or not merged.ok then return nil, refuse("no merge base (unrelated histories or Git failure)") end
  local bases: {string} = {}
  for sha in merged.stdout:gmatch("%S+") do bases[#bases + 1] = sha end
  if #bases ~= 1 then return nil, refuse("ambiguous merge bases") end
  local ancestor = child.run({"git", "merge-base", "--is-ancestor", bases[1], head_sha}, {cwd = root})
  if ancestor == nil or not ancestor.ok then return nil, refuse("merge base is not a proven ancestor of handover") end
  return target_sha, ""
end

local record reviewrange
  resolve: function(board: string, it: item.Item): string | nil, string
end
local M: reviewrange = {resolve = resolve}
return M
