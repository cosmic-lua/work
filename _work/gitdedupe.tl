--- The half-landed-resolution dedupe `_work.gitread.list` applies to
--- its own `for-each-ref` snapshot, exposed as a standalone step over
--- a raw ref listing so `_work.store.list` can compute the SAME
--- `Duplicate` rows from the one snapshot it already took for its own
--- freshness digest, rather than a second `for-each-ref` of its own.
local gitread = require("_work.gitread")
local refs = require("_work.refs")

local type Duplicate = gitread.Duplicate

--- Every id `found` files under both `refs/heads/items` and
--- `refs/heads/ended` at once — the residue of a resolution whose
--- atomic push landed the create half of an old-style namespace move
--- and lost the delete half (the pushing credential can create and
--- update a branch but never delete one). Only a KSUID-shaped tail
--- counts as an item, exactly as `gitread.list` itself filters — a
--- stray branch under either namespace never enters here.
--- @param root string The repository root
--- @param found {refs.RefEntry} A ref listing over the item namespaces
--- @return {Duplicate} Every duplicate found, sorted by id
local function of(root: string, found: {refs.RefEntry}): {Duplicate}
  local items_by_id: {string: refs.RefEntry} = {}
  local ended_by_id: {string: refs.RefEntry} = {}
  for _, r in ipairs(found) do
    local is_items = r.refname:sub(1, #"refs/heads/items/") == "refs/heads/items/"
    local is_ended = r.refname:sub(1, #"refs/heads/ended/") == "refs/heads/ended/"
    if is_items or is_ended then
      local tail = r.refname:match("/([^/]+)$") or ""
      if #tail == 27 and tail:match("^%w+$") then
        if is_items then
          items_by_id[tail] = r
        else
          ended_by_id[tail] = r
        end
      end
    end
  end
  local out: {Duplicate} = {}
  for id, items_e in pairs(items_by_id) do
    local ended_e = ended_by_id[id]
    if ended_e ~= nil then
      local kept, dropped = gitread.pick_duplicate(root, items_e, ended_e)
      out[#out + 1] = {id = id, kept_ref = kept.refname, kept_sha = kept.sha,
        dropped_ref = dropped.refname, dropped_sha = dropped.sha}
    end
  end
  table.sort(out, function(a: Duplicate, b: Duplicate): boolean
      return a.id < b.id
    end)
  return out
end

local record gitdedupe
  of: function(root: string, found: {refs.RefEntry}): {Duplicate}
end

local M: gitdedupe = {
  of = of,
}

return M
