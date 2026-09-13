--- Native board evidence keeps the item attribution alongside global ancestry.
local child = require("cosmic.child")
local evidence = require("_work.commit_evidence")
local gitobj = require("_work.gitobj")
local itemtree = require("_work.itemtree")
local ksuid = require("_work.ksuid")

--- The prose a research handover recorded, read at the commit it named: on one
--- branch a recorded result is a published board commit, so the spec is
--- `<sha>:items/<id>/spec/*` rather than a ref's own tree.
--- @param root string The repository holding `sha`
--- @param sha string The board commit the handover recorded
--- @param id string The item whose prose to read
--- @return itemtree.Spec The prose, both fields "" when the commit has none
local function read_spec(root: string, sha: string, id: string): itemtree.Spec
  local out: itemtree.Spec = {change = "", non_goals = ""}
  if not ksuid.is_id(id) or #sha ~= 40 or not sha:match("^[0-9a-f]+$") then return out end
  local prefix = sha .. ":items/" .. id .. "/spec/"
  local batch = gitobj.cat_file_batch(root, {prefix .. "change.md", prefix .. "non-goals.md"})
  if batch == nil then return out end
  local change, non_goals = batch[prefix .. "change.md"], batch[prefix .. "non-goals.md"]
  if change ~= nil then out.change = change.content end
  if non_goals ~= nil then out.non_goals = non_goals.content end
  return out
end

--- Whether a recorded commit may stand as evidence for `id`: it must be an
--- ancestor of the fetched head AND an event of that item under the reader's
--- own attribution — its diff names `items/<id>/` or `claims/<id>` — so a
--- result recorded on a claim bridge still resolves, and a commit from another
--- item's history never does.
--- @param root string The repository holding `head`
--- @param head string The fetched board head
--- @param result string The commit the handover recorded
--- @param id string The item the evidence must belong to
--- @return boolean True when the commit is this item's published history
--- @return string Error message naming why it is not
local function verify(root: string, head: string, result: string,
    id: string): string | nil, string
  if not ksuid.is_id(id) then return nil, "invalid evidence item id" end
  local lineage, err = evidence.verify_lineage(root, result, head)
  if lineage == nil then return nil, err end
  local history, herr = child.run({"git", "rev-list", "--first-parent", lineage.head}, {cwd = root})
  if history == nil then return nil, herr end
  if not history.ok then return nil, history.stderr end
  if not ("\n" .. history.stdout):find("\n" .. lineage.base .. "\n", 1, true) then
    return nil, "research result is not on the board's first-parent history"
  end
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
