--- Native board evidence keeps the item attribution alongside global ancestry.
local child = require("cosmic.child")
local evidence = require("_work.commit_evidence")
local gitobj = require("_work.gitobj")
local itemtree = require("_work.itemtree")

local function valid_id(id: string): boolean
  return #id == 27 and id:match("^[%w]+$") ~= nil
end

local function read_spec(root: string, sha: string, id: string): itemtree.Spec
  local out: itemtree.Spec = {change = "", non_goals = ""}
  if not valid_id(id) or #sha ~= 40 or not sha:match("^[0-9a-f]+$") then return out end
  local prefix = sha .. ":items/" .. id .. "/spec/"
  local batch = gitobj.cat_file_batch(root, {prefix .. "change.md", prefix .. "non-goals.md"})
  if batch == nil then return out end
  local change, non_goals = batch[prefix .. "change.md"], batch[prefix .. "non-goals.md"]
  if change ~= nil then out.change = change.content end
  if non_goals ~= nil then out.non_goals = non_goals.content end
  return out
end

local function verify(root: string, head: string, result: string,
    id: string): string | nil, string
  if not valid_id(id) then return nil, "invalid evidence item id" end
  local lineage, err = evidence.verify_lineage(root, result, head)
  if lineage == nil then return nil, err end
  local diff, derr = child.run({"git", "diff-tree", "--root", "--no-commit-id",
      "--name-only", "-r", "-z", lineage.base, "--", "items/" .. id,
      "claims/" .. id}, {cwd = root})
  if diff == nil then return nil, derr end
  if not diff.ok then return nil, diff.stderr end
  if diff.stdout == "" then return nil, "research result is not an event of this item" end
  return lineage.base, ""
end

local record stateevidence
  read_spec: function(root: string, sha: string, id: string): itemtree.Spec
  verify: function(root: string, head: string, result: string, id: string): string | nil, string
end

local M: stateevidence = {read_spec = read_spec, verify = verify}
return M
