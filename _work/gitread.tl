--- The store's read path: loading one item and listing the whole
--- board, each in a fixed number of git processes regardless of how
--- many items exist. Split out of `_work.store` so that module stays
--- under its line cap; `_work.store` is the only caller outside tests.
local child = require("cosmic.child")
local gitobj = require("_work.gitobj")
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local refs = require("_work.refs")

--- One item as `load` found it: the item itself, and the ref and tip
--- it was read from — the lease a later `save` writes against.
local record Loaded
  it: item.Item
  ref: string
  sha: string
end

--- The whole board as `list` found it: every item, its ref and tip
--- (`refs_by_id`/`shas_by_id` — the write lease for each), and
--- `refs/board/seq`'s own tip, "" when the ref does not exist yet.
local record Board
  items: {item.Item}
  refs_by_id: {string: string}
  shas_by_id: {string: string}
  seq_sha: string
end

--- Build one item from its tip's `meta`/`beats`/`blocked_by` — shared
--- by `load` (one item, its own two processes) and `list` (the whole
--- board, in two processes total) so the tree-to-Item translation is
--- written once. `batch` and `reasons` are the caller's already-read
--- `cat-file --batch` results; nothing here starts a process.
--- @param id string The item id
--- @param sha string The tip commit this item's tree came from
--- @param batch {string: gitobj.BatchEntry} The meta/beats/blocked_by batch
--- @param reasons {string: gitobj.BatchEntry} Blocker reason blobs, by sha
--- @return item.Item | nil The item
--- @return string Error message; set only when `meta` itself is missing
local function build_item(id: string, sha: string,
    batch: {string: gitobj.BatchEntry},
    reasons: {string: gitobj.BatchEntry}): item.Item | nil, string
  local meta_entry = batch[sha .. ":meta"]
  if meta_entry == nil then
    return nil, ("%s: no meta at %s"):format(id, sha)
  end
  local meta = itemtree.parse_meta(meta_entry.content)
  local beats: {string} = {}
  local beats_entry = batch[sha .. ":beats"]
  if beats_entry ~= nil then
    for _, e in ipairs(gitobj.parse_tree(beats_entry.content)) do
      beats[#beats + 1] = e.name
    end
  end
  local blocked_by: {string} = {}
  local block_reason: {string: string} = {}
  local blocked_entry = batch[sha .. ":blocked_by"]
  if blocked_entry ~= nil then
    for _, e in ipairs(gitobj.parse_tree(blocked_entry.content)) do
      blocked_by[#blocked_by + 1] = e.name
      local re = reasons[e.sha]
      if re ~= nil and re.content ~= "" then
        block_reason[e.name] = re.content
      end
    end
  end
  return itemtree.to_item(id, meta, beats, blocked_by, block_reason)
end

--- Load one item by id, looking in `refs/items` then `refs/ended`.
--- @param root string The repository root
--- @param id string Item id
--- @return Loaded | nil The item, its ref and its tip
--- @return string Error message; "no item <id>" when absent
local function load_item(root: string, id: string): Loaded | nil, string
  local found, ferr = refs.for_each_ref(root, {"refs/items/" .. id, "refs/ended/" .. id})
  if found == nil then
    return nil, ferr
  end
  if #found == 0 then
    return nil, ("no item %s"):format(id)
  end
  local ref, sha = found[1].refname, found[1].sha
  local batch, berr = gitobj.cat_file_batch(root,
    {sha .. ":meta", sha .. ":beats", sha .. ":blocked_by"})
  if batch == nil then
    return nil, berr
  end
  local blocked_entry = batch[sha .. ":blocked_by"]
  local reason_queries: {string} = {}
  if blocked_entry ~= nil then
    for _, e in ipairs(gitobj.parse_tree(blocked_entry.content)) do
      reason_queries[#reason_queries + 1] = e.sha
    end
  end
  local reasons, rerr = gitobj.cat_file_batch(root, reason_queries)
  if reasons == nil then
    return nil, rerr
  end
  local it, ierr = build_item(id, sha, batch, reasons)
  if it == nil then
    return nil, ierr
  end
  return {it = it, ref = ref, sha = sha}
end

--- Every item in the store, done ones included: one `for-each-ref`
--- (also reading `refs/board/seq`'s tip), one `cat-file --batch` for
--- every item's `meta`/`beats`/`blocked_by`, and one more for every
--- blocker's reason blob — three processes total, never one per item.
--- @param root string The repository root
--- @return Board | nil The board
--- @return string Error message naming the first genuinely corrupt item
local function list(root: string): Board | nil, string
  local found, ferr = refs.for_each_ref(root, {"refs/items", "refs/ended", "refs/board"})
  if found == nil then
    return nil, ferr
  end
  local item_refs: {refs.RefEntry} = {}
  local seq_sha = ""
  for _, r in ipairs(found) do
    if r.refname == "refs/board/seq" then
      seq_sha = r.sha
    elseif r.refname:sub(1, 11) == "refs/items/" or r.refname:sub(1, 11) == "refs/ended/" then
      item_refs[#item_refs + 1] = r
    end
  end
  local queries: {string} = {}
  for _, r in ipairs(item_refs) do
    queries[#queries + 1] = r.sha .. ":meta"
    queries[#queries + 1] = r.sha .. ":beats"
    queries[#queries + 1] = r.sha .. ":blocked_by"
  end
  local batch, berr = gitobj.cat_file_batch(root, queries)
  if batch == nil then
    return nil, berr
  end
  local reason_queries: {string} = {}
  for _, r in ipairs(item_refs) do
    local blocked_entry = batch[r.sha .. ":blocked_by"]
    if blocked_entry ~= nil then
      for _, e in ipairs(gitobj.parse_tree(blocked_entry.content)) do
        reason_queries[#reason_queries + 1] = e.sha
      end
    end
  end
  local reasons, rerr = gitobj.cat_file_batch(root, reason_queries)
  if reasons == nil then
    return nil, rerr
  end
  local items: {item.Item} = {}
  local refs_by_id: {string: string} = {}
  local shas_by_id: {string: string} = {}
  for _, r in ipairs(item_refs) do
    local id = r.refname:match("^refs/items/(.+)$") or r.refname:match("^refs/ended/(.+)$")
    local it, ierr = build_item(id, r.sha, batch, reasons)
    if it == nil then
      return nil, ierr
    end
    items[#items + 1] = it
    refs_by_id[id] = r.refname
    shas_by_id[id] = r.sha
  end
  table.sort(items, function(a: item.Item, b: item.Item): boolean
    return a.id < b.id
  end)
  return {items = items, refs_by_id = refs_by_id, shas_by_id = shas_by_id, seq_sha = seq_sha}
end

--- An item's spec sidecar, "" when absent, tried against every
--- candidate ref in order — `_work.store` passes the observed ref
--- alone when known, or both `refs/items/<id>` and `refs/ended/<id>`
--- otherwise.
--- @param root string The repository root
--- @param candidates {string} Ref names to try, in order
--- @return string The spec markdown, possibly empty
local function read_spec(root: string, candidates: {string}): string
  for _, ref in ipairs(candidates) do
    local r = child.run({"git", "cat-file", "-p", ref .. ":spec.md"}, {cwd = root})
    if r ~= nil and r.ok then
      return r.stdout
    end
  end
  return ""
end

local record gitread
  type Loaded = Loaded
  type Board = Board
  load: function(root: string, id: string): Loaded | nil, string
  list: function(root: string): Board | nil, string
  read_spec: function(root: string, candidates: {string}): string
end

local M: gitread = {
  load = load_item,
  list = list,
  read_spec = read_spec,
}

return M
