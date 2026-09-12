--- An item's spec prose, read from its ref. Beside
--- `_work.gitreadlog`'s commit-message reads in role — the same store
--- read layer, the same tolerant empty answer for what a ref does not
--- carry — and split into its own file purely to keep `_work.gitread`
--- under the repo's line cap, exactly as `_work.gitreadmany` and
--- `_work.gitreadlog` are.
---
--- Format 5 holds the prose as a `spec/` subtree of two blobs
--- (`_work.itemtree`'s `Spec`); format 4 held one `spec.md`. Both are
--- read here, in one `cat-file --batch` that asks for every path of
--- every candidate at once, and this is the ONE place the old shape is
--- known about.
local gitobj = require("_work.gitobj")
local itemtree = require("_work.itemtree")
local refs = require("_work.refs")

--- One object's spec prose, read from a batch that asked for all three
--- of its spec paths — nil when the object carries none of them, which
--- is what lets `read_spec` fall through to its next candidate. A
--- format-4 tree holds a single `spec.md`, read as the `change` field:
--- the one tolerant read of the old shape, and the only place it is
--- known about.
--- @param batch {string: gitobj.BatchEntry} The batch's answers
--- @param object string The ref name or object id the queries were built from
--- @return itemtree.Spec | nil The prose, nil when the object has none
local function spec_in_batch(batch: {string: gitobj.BatchEntry},
    object: string): itemtree.Spec | nil
  local change = batch[object .. ":spec/change.md"]
  local non_goals = batch[object .. ":spec/non-goals.md"]
  if change ~= nil or non_goals ~= nil then
    local sp: itemtree.Spec = {change = "", non_goals = ""}
    if change ~= nil then
      sp.change = change.content
    end
    if non_goals ~= nil then
      sp.non_goals = non_goals.content
    end
    return sp
  end
  local legacy = batch[object .. ":spec.md"]
  if legacy == nil then
    return nil
  end
  return {change = legacy.content, non_goals = ""}
end

--- The three paths one object's prose can live at, appended to a batch
--- being built: the format-5 subtree's two blobs and the format-4
--- single blob.
--- @param queries {string} The batch being built, appended to
--- @param object string The ref name or object id to read
local function spec_queries(queries: {string}, object: string)
  queries[#queries + 1] = object .. ":spec/change.md"
  queries[#queries + 1] = object .. ":spec/non-goals.md"
  queries[#queries + 1] = object .. ":spec.md"
end

--- An item's spec prose, both fields "" when absent, tried against every
--- candidate ref in order — `_work.store` passes the observed ref alone
--- when known, or both `refs/heads/items/<id>` and
--- `refs/heads/ended/<id>` otherwise. One `cat-file --batch` for every
--- candidate and path together, so the cost does not grow with either.
--- @param root string The repository root
--- @param candidates {string} Ref names to try, in order
--- @return itemtree.Spec The prose, both fields "" when it has none
local function read_spec(root: string, candidates: {string}): itemtree.Spec
  local objects: {string} = {}
  local queries: {string} = {}
  for _, ref in ipairs(candidates) do
    -- `refs.for_each_ref` deliberately presents canonical entries
    -- under their transport-neutral `refs/heads/*` names: those are
    -- the names a later write publishes to, not necessarily the refs
    -- a remote-backed checkout reads. Map a board ref back through the
    -- configured mode before dereferencing it. A raw object id (used
    -- by claim preparation) is already unambiguous and passes through
    -- unchanged.
    local object = ref
    if ref:match("^refs/heads/") ~= nil then
      local canonical = refs.canonical_ref(root, ref)
      if canonical ~= nil then
        object = canonical
      end
    end
    objects[#objects + 1] = object
    spec_queries(queries, object)
  end
  local batch = gitobj.cat_file_batch(root, queries)
  if batch ~= nil then
    for _, object in ipairs(objects) do
      local sp = spec_in_batch(batch, object)
      if sp ~= nil then
        return sp
      end
    end
  end
  return {change = "", non_goals = ""}
end

--- Every named item's spec prose in one batch, both fields "" for an id
--- that has none or whose tip is unknown — the whole-board counterpart
--- to `read_spec`, so a readiness pass over every item costs one more
--- `cat-file --batch` instead of one process per item.
--- @param root string The repository root
--- @param shas_by_id {string: string} Each item's tip sha, from `list`
--- @param ids {string} Item ids to read, in any order
--- @return {string: itemtree.Spec} Prose by id, both fields "" when absent
local function read_specs(root: string, shas_by_id: {string: string},
    ids: {string}): {string: itemtree.Spec}
  local result: {string: itemtree.Spec} = {}
  local queries: {string} = {}
  local object_of: {string: string} = {}
  for _, id in ipairs(ids) do
    result[id] = {change = "", non_goals = ""}
    local sha = shas_by_id[id]
    if sha ~= nil then
      object_of[id] = sha
      spec_queries(queries, sha)
    end
  end
  local batch = gitobj.cat_file_batch(root, queries)
  if batch == nil then
    return result
  end
  for _, id in ipairs(ids) do
    local object = object_of[id]
    if object ~= nil then
      local sp = spec_in_batch(batch, object)
      if sp ~= nil then
        result[id] = sp
      end
    end
  end
  return result
end

local record gitreadspec
  read_spec: function(root: string, candidates: {string}): itemtree.Spec
  read_specs: function(root: string, shas_by_id: {string: string},
  ids: {string}): {string: itemtree.Spec}
end

local M: gitreadspec = {
  read_spec = read_spec,
  read_specs = read_specs,
}

return M
