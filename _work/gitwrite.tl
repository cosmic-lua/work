--- The store's write path: turning one mutation's items into git
--- commits and moving their refs locally, leaving the push itself to
--- `_work.publish`. Split out of `_work.store` so that module stays
--- under its line cap; `_work.store` is the only caller outside tests.
local gitobj = require("_work.gitobj")
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local refs = require("_work.refs")

--- The tool's own git identity — the committer on every commit, and
--- the author too when no session claimed the mutation.
local TOOL_NAME < const > = "Claude"
local TOOL_EMAIL < const > = "noreply@anthropic.com"

--- One `save` call's inputs: the items to write (`items[1]` is the
--- primary `it`, the rest are `also`), the identity and trailer to
--- write them under, the lease each was last observed at, and — for a
--- BOUNDED mutation — `refs/board/seq`'s own observed tip.
local record Request
  root: string
  items: {item.Item}
  message: string
  session: string
  op: string
  --- Replacement spec for `items[1]`; nil leaves it exactly as
  --- observed. Every other item's sidecar is always carried forward
  --- unchanged — `read_spec` is how its current text is found.
  spec_for_first: string | nil
  leased_ref: {string: string}
  leased_sha: {string: string}
  bounded: boolean
  seq_sha: string
  read_spec: function(id: string): string
end

--- What `save_batch` did: the refs to push, each item's new ref and
--- tip (for the caller to update its own lease table with), whether
--- anything changed at all, and — for a bounded mutation — whether
--- `refs/board/seq` moved and its new tip.
local record Outcome
  pushes: {refs.PushSpec}
  new_ref: {string: string}
  new_sha: {string: string}
  changed: boolean
  seq_changed: boolean
  new_seq_sha: string
end

--- Build and commit one item's tree when it moved, and stage the ref
--- move locally. Returns whether the tree actually changed; when it
--- did, `out` gains the push(es) and the item's new lease.
--- @param req Request The save request
--- @param it item.Item The item to write
--- @param spec_body string The sidecar to write alongside it
--- @param out Outcome Accumulator `out.pushes`/`new_ref`/`new_sha` are appended to
--- @return boolean True when the tree changed and was committed
--- @return string Error message
local function write_one(req: Request, it: item.Item, spec_body: string,
    out: Outcome): boolean, string
  local ref = req.leased_ref[it.id] or ("refs/items/" .. it.id)
  local old_sha = req.leased_sha[it.id] or refs.ZERO_SHA
  local tree_sha, terr = itemtree.build_tree(req.root, it, spec_body)
  if tree_sha == nil then
    return false, terr
  end
  local old_tree = ""
  if old_sha ~= refs.ZERO_SHA then
    local t, oerr = gitobj.tree_of(req.root, old_sha)
    if t == nil then
      return false, ("could not read %s's observed tree: %s"):format(it.id, oerr)
    end
    old_tree = t
  end
  if tree_sha == old_tree then
    return false, ""
  end
  local parents: {string} = {}
  if old_sha ~= refs.ZERO_SHA then
    parents = {old_sha}
  end
  local author_name, author_email = TOOL_NAME, TOOL_EMAIL
  if (req.session or "") ~= "" then
    author_name, author_email = req.session, req.session .. "@board"
  end
  local commit_sha, cerr = gitobj.commit_tree(req.root, {
      tree = tree_sha, parents = parents, message = req.message,
      author_name = author_name, author_email = author_email,
      committer_name = TOOL_NAME, committer_email = TOOL_EMAIL,
      op = req.op or "",
    })
  if commit_sha == nil then
    return false, cerr
  end
  if (it.resolution or "") ~= "" and ref:sub(1, 11) == "refs/items/" then
    local moved, merr = refs.move_to_ended(req.root, it.id, commit_sha, old_sha)
    if not moved then
      return false, merr
    end
    out.pushes[#out.pushes + 1] = {ref = "refs/ended/" .. it.id, old = "", delete = false}
    out.pushes[#out.pushes + 1] = {ref = "refs/items/" .. it.id, old = old_sha, delete = true}
    out.new_ref[it.id], out.new_sha[it.id] = "refs/ended/" .. it.id, commit_sha
  else
    local moved, uerr = refs.update_ref(req.root, ref, commit_sha, old_sha)
    if not moved then
      return false, uerr
    end
    out.pushes[#out.pushes + 1] = {ref = ref, old = old_sha, delete = false}
    out.new_ref[it.id], out.new_sha[it.id] = ref, commit_sha
  end
  return true, ""
end

--- Advance `refs/board/seq` by one empty-tree commit and stage its
--- move locally — a bounded mutation's idempotency-free lease bump,
--- so two racing bounded mutations cannot both land.
--- @param req Request The save request
--- @param out Outcome Accumulator; `out.pushes` gains the seq push
--- @return boolean True on success
--- @return string Error message
local function advance_seq(req: Request, out: Outcome): boolean, string
  local seq_old = refs.ZERO_SHA
  if (req.seq_sha or "") ~= "" then
    seq_old = req.seq_sha
  end
  local empty_tree, eerr = gitobj.mktree(req.root, {})
  if empty_tree == nil then
    return false, eerr
  end
  local parents: {string} = {}
  if seq_old ~= refs.ZERO_SHA then
    parents = {seq_old}
  end
  local seq_commit, serr = gitobj.commit_tree(req.root, {
      tree = empty_tree, parents = parents, message = req.message,
      author_name = TOOL_NAME, author_email = TOOL_EMAIL,
      committer_name = TOOL_NAME, committer_email = TOOL_EMAIL,
      op = req.op or "",
    })
  if seq_commit == nil then
    return false, serr
  end
  local moved, uerr = refs.update_ref(req.root, "refs/board/seq", seq_commit, seq_old)
  if not moved then
    return false, uerr
  end
  out.pushes[#out.pushes + 1] = {ref = "refs/board/seq", old = seq_old, delete = false}
  out.seq_changed, out.new_seq_sha = true, seq_commit
  return true, ""
end

--- Write every item in `req.items`, each as its own commit when its
--- tree moved, and — when `req.bounded` — advance `refs/board/seq`
--- too, all staged locally and left in `Outcome.pushes` for `publish`
--- to push together.
--- @param req Request The save request
--- @return Outcome | nil What moved
--- @return string Error message
local function save_batch(req: Request): Outcome | nil, string
  local out: Outcome = {pushes = {}, new_ref = {}, new_sha = {}, changed = false,
    seq_changed = false, new_seq_sha = ""}
  for idx, it in ipairs(req.items) do
    local spec_body: string
    if idx == 1 and req.spec_for_first ~= nil then
      spec_body = req.spec_for_first
    else
      spec_body = req.read_spec(it.id)
    end
    local changed, err = write_one(req, it, spec_body, out)
    if err ~= "" then
      return nil, err
    end
    if changed then
      out.changed = true
    end
  end
  if not out.changed then
    return out, ""
  end
  if req.bounded then
    local ok, serr = advance_seq(req, out)
    if not ok then
      return nil, serr
    end
  end
  return out, ""
end

local record gitwrite
  type Request = Request
  type Outcome = Outcome
  save_batch: function(req: Request): Outcome | nil, string
end

local M: gitwrite = {
  save_batch = save_batch,
}

return M
