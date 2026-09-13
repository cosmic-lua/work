--- Explicit native-board bootstrap. Existing legacy boards require migration.
local boardtree = require("_work.boardtree")
local child = require("cosmic.child")
local fs = require("cosmic.fs")
local gitobj = require("_work.gitobj")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local refs = require("_work.refs")
local storeinit = require("_work.storeinit")

--- Create an empty format-6 board in `root`: the `format` marker at 6, one
--- board item, and `refs/heads/state` carrying both. A repository that already
--- holds legacy item, ended or claim-batch refs is refused rather than
--- half-converted — moving such a board is `migrate6`'s job.
--- @param root string The directory to initialise, `git init`ed when bare of one
--- @return boolean True when the board exists and carries the marker
--- @return string Error message
local function init(root: string): boolean, string
  local denied = storeinit.linked_worktree_refusal(root)
  if denied ~= nil then return false, denied end
  if not fs.is_dir(fs.join(root, ".git")) then
    local made, err = child.run({"git", "init", "-q", root})
    if made == nil then return false, err end
    if not made.ok then return false, made.stderr end
  end
  local present, perr = refs.for_each_ref_raw(root,
    {"refs/heads/items", "refs/heads/ended", "refs/heads/claim-batches",
      "refs/heads/board", "refs/heads/state", "refs/remotes"})
  if present == nil then return false, perr end
  local marker, merr = refs.read_ref(root, "refs/heads/board/format")
  if marker == nil then return false, merr end
  if marker ~= refs.ZERO_SHA then
    local got = gitobj.cat_file_batch(root, {marker .. ":format"})
    local current = got and got[marker .. ":format"]
    if current == nil or current.content ~= "6\n" then
      return false, "REFUSED: existing format marker requires migrate6"
    end
    local head, herr = refs.read_ref(root, "refs/heads/state")
    if head == nil then return false, herr end
    if head == refs.ZERO_SHA then return false, "format 6 marker has no state head" end
    return true, ""
  end
  for _, entry in ipairs(present) do
    if entry.refname:match("/items/") or entry.refname:match("/ended/")
    or entry.refname:match("/claim%-batches/") then
      return false, "REFUSED: existing board data requires migrate6, not init --format 6"
    end
  end
  local existing, xerr = refs.read_ref(root, "refs/heads/state")
  if existing == nil then return false, xerr end
  if existing ~= refs.ZERO_SHA then return false, "REFUSED: unactivated state exists; inspect its migration" end
  local board: item.Item = {id = ksuid.new(), title = "board", parent = "",
    repo = "", base = "", order = {}, claim = "", builders = {}, speccers = {},
    reviewer = "", pr = 0, result = "", verdict = "", verdict_head = "", resolution = ""}
  local subtree, serr = boardtree.build_item(root, board, nil, nil, true)
  if subtree == nil then return false, serr end
  local items, ierr = gitobj.mktree_write(root,
    {{mode = "40000", otype = "tree", name = board.id, sha = subtree}})
  if items == nil then return false, ierr end
  local blob, berr = gitobj.hash_object_write(root, "6\n")
  if blob == nil then return false, berr end
  local tree, terr = gitobj.mktree_write(root, {
      {mode = "100644", otype = "blob", name = "format", sha = blob},
      {mode = "40000", otype = "tree", name = "items", sha = items}})
  if tree == nil then return false, terr end
  local head, herr = gitobj.commit_tree(root, {tree = tree, parents = {},
      message = "initialize format-6 board", author_name = "gitboard",
      author_email = "gitboard@localhost", committer_name = "gitboard",
      committer_email = "gitboard@localhost"})
  if head == nil then return false, herr end
  local specs, rerr = refs.ensure_refspecs(root)
  if not specs then return false, rerr end
  return refs.update_refs_atomic(root, {
      {ref = "refs/heads/state", expected = refs.ZERO_SHA, next = head},
      {ref = "refs/heads/board/format", expected = refs.ZERO_SHA, next = head}})
end

local record stateinit
  init: function(root: string): boolean, string
end
local M: stateinit = {init = init}
return M
