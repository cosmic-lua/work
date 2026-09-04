--- `_work.gitread.load`'s batched counterpart for a caller-named SET
--- of ids, split into its own file purely to keep `_work.gitread`
--- under the repo's line cap — the read-path primitives it needs
--- (`edge_kinds`, `content_blob_shas`, `build_item`, `pick_duplicate`)
--- are that module's own, exported for exactly this reuse rather than
--- duplicated here. `_work.cache`'s fetch-path refresh is the only
--- caller outside tests: a fetch can land a version nobody observed
--- directly, so it always rereads the ids it moved, in one batch
--- rather than one `_work.gitread.load` per id.
local gitobj = require("_work.gitobj")
local gitread = require("_work.gitread")
local refs = require("_work.refs")

local type Loaded = gitread.Loaded

--- Load a specific set of items by id, in the same fixed handful of
--- processes `gitread.list` uses for the whole board. An id present in
--- neither namespace (a locally pruned ref) is simply absent from the
--- result, never an error: the caller reads that the same way
--- `_work.cache.patch_item`'s deleted-item branch always has, as
--- "genuinely gone." An id present under BOTH `refs/heads/items` and
--- `refs/heads/ended` — the half-landed-resolution residue
--- `gitread.list` tolerates — is resolved through the same
--- `gitread.pick_duplicate` rule `gitread.list`/`gitread.load` use,
--- never by which of the two `for-each-ref` results happened to come
--- back last.
--- @param root string The repository root
--- @param ids {string} Item ids to read, in any order
--- @return {string: Loaded} | nil Loaded items by id, only those found
--- @return string Error message: a hard failure reading git objects
local function load_many(root: string, ids: {string}): {string: Loaded} | nil, string
  local out: {string: Loaded} = {}
  if #ids == 0 then
    return out
  end
  local patterns: {string} = {}
  for _, id in ipairs(ids) do
    patterns[#patterns + 1] = "refs/heads/items/" .. id
    patterns[#patterns + 1] = "refs/heads/ended/" .. id
  end
  local found, ferr = refs.for_each_ref(root, patterns)
  if found == nil then
    return nil, ferr
  end
  local items_by_id: {string: refs.RefEntry} = {}
  local ended_by_id: {string: refs.RefEntry} = {}
  for _, r in ipairs(found) do
    local id = r.refname:match("^refs/heads/items/(.+)$")
    if id ~= nil then
      items_by_id[id] = r
    else
      id = r.refname:match("^refs/heads/ended/(.+)$")
      if id ~= nil then
        ended_by_id[id] = r
      end
    end
  end
  local resolved: {refs.RefEntry} = {}
  for _, id in ipairs(ids) do
    local items_e, ended_e = items_by_id[id], ended_by_id[id]
    if items_e ~= nil and ended_e ~= nil then
      local kept = gitread.pick_duplicate(root, items_e, ended_e)
      resolved[#resolved + 1] = kept
    elseif items_e ~= nil then
      resolved[#resolved + 1] = items_e
    elseif ended_e ~= nil then
      resolved[#resolved + 1] = ended_e
    end
  end
  local queries: {string} = {}
  for _, r in ipairs(resolved) do
    queries[#queries + 1] = r.sha .. ":meta"
    queries[#queries + 1] = r.sha .. ":held"
    queries[#queries + 1] = r.sha .. ":edges"
  end
  local batch, berr = gitobj.cat_file_batch(root, queries)
  if batch == nil then
    return nil, berr
  end
  local kinds_by_ref: {string: {string: string}} = {}
  local kind_queries: {string} = {}
  for _, r in ipairs(resolved) do
    local edges_entry = batch[r.sha .. ":edges"]
    if edges_entry ~= nil then
      local kinds = gitread.edge_kinds(edges_entry.content)
      kinds_by_ref[r.refname] = kinds
      for _, ksha in pairs(kinds) do
        kind_queries[#kind_queries + 1] = ksha
      end
    end
  end
  local kind_batch, kerr = gitobj.cat_file_batch(root, kind_queries)
  if kind_batch == nil then
    return nil, kerr
  end
  local blob_queries: {string} = {}
  for _, r in ipairs(resolved) do
    local kinds = kinds_by_ref[r.refname]
    if kinds ~= nil then
      for _, sha in ipairs(gitread.content_blob_shas(kinds, kind_batch)) do
        blob_queries[#blob_queries + 1] = sha
      end
    end
  end
  local blob_batch, rerr = gitobj.cat_file_batch(root, blob_queries)
  if blob_batch == nil then
    return nil, rerr
  end
  for _, r in ipairs(resolved) do
    local id = r.refname:match("^refs/heads/items/(.+)$") or r.refname:match("^refs/heads/ended/(.+)$")
    if id ~= nil then
      local it, ierr = gitread.build_item(id, r.sha, batch, kind_batch, blob_batch)
      if it == nil then
        return nil, ierr
      end
      out[id] = {it = it, ref = r.refname, sha = r.sha}
    end
  end
  return out
end

local record gitreadmany
  load_many: function(root: string, ids: {string}): {string: Loaded} | nil, string
end

local M: gitreadmany = {
  load_many = load_many,
}

return M
