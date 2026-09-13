--- Decode one exact format-6 head. No ref is resolved after the caller supplies
--- `head`, so all fields belong to one immutable snapshot.
local boardtree = require("_work.boardtree")
local gitobj = require("_work.gitobj")
local item = require("_work.item")
local itemtree = require("_work.itemtree")

local record boardread
  record Decoded
    it: item.Item spec: itemtree.Spec claim: boardtree.Claim | nil
    logs: {string: string} tree: string claim_blob: string
  end
  record View
    head: string items: {item.Item} items_by_id: {string: item.Item}
    specs_by_id: {string: itemtree.Spec} claims_by_id: {string: boardtree.Claim}
    logs_by_id: {string: {string: string}} item_tree_by_id: {string: string}
    claim_blob_by_id: {string: string} entries: {boardtree.Entry}
    marks: {string: string}
  end
  list: function(root: string, head: string, now?: integer): View | nil, string
  load: function(string, string, string): Decoded | nil, string
end
local type Decoded = boardread.Decoded
local type View = boardread.View

local function list(root: string, head: string, now?: integer): View | nil, string
  local all_entries, err = boardtree.snapshot_tree_entries(root, head)
  if all_entries == nil then return nil, err end
  local entries: {boardtree.Entry} = {}
  local item_trees: {string: string} = {}
  for _, e in ipairs(all_entries) do
    local tree_id = e.path:match("^items/([^/]+)$")
    if tree_id ~= nil and (e.mode == "040000" or e.mode == "40000") then item_trees[tree_id] = e.sha end
    if e.mode ~= "040000" and e.mode ~= "40000" then entries[#entries + 1] = e end
  end
  local queries: {string} = {}
  for _, e in ipairs(entries) do queries[#queries + 1] = e.sha end
  local blobs, berr = gitobj.cat_file_batch(root, queries)
  if blobs == nil then return nil, berr end
  local metas: {string: {string: string}} = {}
  local orders: {string: {string}} = {}
  local edges: {string: {string: {string: string}}} = {}
  local specs: {string: itemtree.Spec} = {}
  local logs: {string: {string: string}} = {}
  local claims: {string: boardtree.Claim} = {}
  local claim_shas: {string: string} = {}
  local marks: {string: string} = {}
  local ids: {string: boolean} = {}
  for _, e in ipairs(entries) do
    local content = blobs[e.sha] and blobs[e.sha].content or ""
    local id = e.path:match("^items/([^/]+)/")
    if id ~= nil then
      ids[id] = true
      if e.path == "items/" .. id .. "/meta" then metas[id] = itemtree.parse_meta(content)
      elseif e.path == "items/" .. id .. "/order" then orders[id] = itemtree.parse_order(content)
      elseif e.path == "items/" .. id .. "/spec/change.md" then
        specs[id] = specs[id] or {change = "", non_goals = ""}; specs[id].change = content
      elseif e.path == "items/" .. id .. "/spec/non-goals.md" then
        specs[id] = specs[id] or {change = "", non_goals = ""}; specs[id].non_goals = content
      else
        local kind, target = e.path:match("^items/[^/]+/edges/([^/]+)/([^/]+)$")
        if kind ~= nil then
          edges[id] = edges[id] or {}; edges[id][kind] = edges[id][kind] or {}
          edges[id][kind][target] = content
        end
        local logid = e.path:match("^items/[^/]+/log/([^/]+)%.md$")
        if logid ~= nil then logs[id] = logs[id] or {}; logs[id][logid] = content end
      end
    else
      local claim_id = e.path:match("^claims/([^/]+)$")
      if claim_id ~= nil then
        local st, cerr = boardtree.decode_claim(content)
        if st == nil then return nil, "claims/" .. claim_id .. ": " .. (cerr or "invalid claim") end
        claims[claim_id], claim_shas[claim_id] = st, e.sha
      elseif e.path == "migration/marks" then
        local decoded, merr = boardtree.decode_marks(content)
        if decoded == nil then return nil, merr end
        marks = decoded
      end
    end
  end
  local out: View = {head = head, items = {}, items_by_id = {}, specs_by_id = specs,
    claims_by_id = claims, logs_by_id = logs, item_tree_by_id = item_trees,
    claim_blob_by_id = claim_shas, entries = entries, marks = marks}
  local sorted: {string} = {}; for id in pairs(ids) do sorted[#sorted + 1] = id end; table.sort(sorted)
  for _, id in ipairs(sorted) do
    if metas[id] == nil then return nil, "items/" .. id .. " has no meta" end
    local it = itemtree.to_item(id, metas[id], false, orders[id] or {}, edges[id] or {})
    local st = claims[id]
    if st ~= nil then
      local at = now or os.time()
      if st.renewed_at > at + 300 then return nil, "claim for " .. id .. " is more than five minutes in the future" end
      it.claim_base, it.claim_batch = st.product_base, st.id
      if at < st.expires_at then it.claim = st.holder end
    end
    out.items[#out.items + 1], out.items_by_id[id] = it, it
    if out.item_tree_by_id[id] == nil then return nil, "items/" .. id .. " has no tree" end
    out.specs_by_id[id] = out.specs_by_id[id] or {change = "", non_goals = ""}
    out.logs_by_id[id] = out.logs_by_id[id] or {}
  end
  return out
end

local function load_item(root: string, head: string, id: string): Decoded | nil, string
  local view, err = list(root, head); if view == nil then return nil, err end
  local it = view.items_by_id[id]; if it == nil then return nil, "item not found: " .. id end
  return {it = it, spec = view.specs_by_id[id], claim = view.claims_by_id[id],
    logs = view.logs_by_id[id], tree = view.item_tree_by_id[id],
    claim_blob = view.claim_blob_by_id[id] or boardtree.ZERO_SHA}
end

local M: boardread = {list = list, load = load_item}
return M
