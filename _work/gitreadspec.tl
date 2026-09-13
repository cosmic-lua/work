--- An item's spec prose, read from its ref. Beside
--- `_work.gitreadlog`'s commit-message reads in role — the same store
--- read layer, the same tolerant empty answer for what a ref does not
--- carry — and split into its own file purely to keep `_work.gitread`
--- under the repo's line cap, exactly as `_work.gitreadmany` and
--- `_work.gitreadlog` are.
---
--- The prose is a `spec/` subtree of two blobs (`_work.itemtree`'s
--- `Spec`), read here in one `cat-file --batch` that asks for both
--- paths of every candidate at once.
local format = require("_work.format")
local gitobj = require("_work.gitobj")
local itemtree = require("_work.itemtree")
local refs = require("_work.refs")

--- One object's spec prose, read from a batch that asked for both of
--- its spec paths — nil when the object carries neither, which is what
--- lets `read_spec` fall through to its next candidate.
--- @param batch {string: gitobj.BatchEntry} The batch's answers
--- @param object string The ref name or object id the queries were built from
--- @return itemtree.Spec | nil The prose, nil when the object has none
local function spec_in_batch(batch: {string: gitobj.BatchEntry},
    object: string): itemtree.Spec | nil
  local change = batch[object .. ":spec/change.md"]
  local non_goals = batch[object .. ":spec/non-goals.md"]
  if change == nil and non_goals == nil then
    return nil
  end
  local sp: itemtree.Spec = {change = "", non_goals = ""}
  if change ~= nil then
    sp.change = change.content
  end
  if non_goals ~= nil then
    sp.non_goals = non_goals.content
  end
  return sp
end

--- The two paths one object's prose lives at, appended to a batch
--- being built.
--- @param queries {string} The batch being built, appended to
--- @param object string The ref name or object id to read
local function spec_queries(queries: {string}, object: string)
  queries[#queries + 1] = object .. ":spec/change.md"
  queries[#queries + 1] = object .. ":spec/non-goals.md"
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
---
--- On format 6 every id reads as `<head>:items/<id>/spec/*`; `native_mode`
--- says which layout the given shas name, and a caller that knows (the
--- store's own `state_head`, or the board a rebuild already classified)
--- passes it rather than paying for a marker read here. A NATIVE read
--- fails CLOSED: an unreadable marker, an unreadable batch, or an item
--- subtree with no `meta` throws rather than answering empty prose, since
--- this function is infallible by type and a silent "" would read as an
--- item with no spec — the one answer a corrupt native board must not
--- produce. The legacy half keeps its tolerant empty answer, where an
--- absent tip is ordinary rather than corruption.
--- @param root string The repository root
--- @param shas_by_id {string: string} Each item's tip sha, from `list` —
--- on format 6, the one state head every id is read at
--- @param ids {string} Item ids to read, in any order
--- @param native_mode boolean | nil Whether these shas name format-6 state
--- commits; nil reads the marker to find out, and throws its refusal
--- @return {string: itemtree.Spec} Prose by id, both fields "" when absent
local function read_specs(root: string, shas_by_id: {string: string},
    ids: {string}, native_mode?: boolean): {string: itemtree.Spec}
  local is_native = native_mode
  if is_native == nil then
    local head, err = format.state_head(root)
    -- throws: an infallible-by-type read cannot report an unknown board format
    if head == nil then error(err, 0) end
    is_native = head ~= ""
  end
  if is_native then
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
  ids: {string}, native_mode?: boolean): {string: itemtree.Spec}
end

local M: gitreadspec = {
  read_spec = read_spec,
  read_specs = read_specs,
}

return M
