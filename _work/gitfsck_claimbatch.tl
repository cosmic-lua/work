--- Format-4 shared claim-batch graph validation for `gitboard fsck`.
--- Kept separate from the cache audit so both modules stay small enough for
--- the project's strict lint cap.
local proc = require("cosmic.child")
local claimbatch = require("_work.claimbatch")
local gitobj = require("_work.gitobj")
local itemtree = require("_work.itemtree")
local refs = require("_work.refs")
local store = require("_work.store")

local record ItemTip
  id: string
  tip: string
  pointer: string
end

local function is_item_id(value: string): boolean
  return #value == 27 and value:match("^%w+$") ~= nil
end

--- Use the same descendant-or-ended rule as the normal reader while keeping
--- this pass independent of item projection, which is allowed to fail closed.
local function item_tips(s: store.Store,
    found: {refs.RefEntry}): {string: ItemTip}
  local out: {string: ItemTip} = {}
  for _, r in ipairs(found) do
    local id = r.refname:match("^refs/heads/items/(.+)$")
    or r.refname:match("^refs/heads/ended/(.+)$")
    if id ~= nil and is_item_id(id) then
      local before = out[id]
      if before == nil then
        out[id] = {id = id, tip = r.sha, pointer = ""}
      else
        local replace = refs.is_ancestor(s.root, before.tip, r.sha)
        if not replace and not refs.is_ancestor(s.root, r.sha, before.tip) then
          replace = r.refname:match("^refs/heads/ended/") ~= nil
        end
        if replace then out[id] = {id = id, tip = r.sha, pointer = ""} end
      end
    end
  end
  return out
end

--- In one walk and one object batch, build the information needed to prove a
--- bridge: its parent and the claim-batch pointer in its tree.
local function history(s: store.Store, items: {string: ItemTip}):
  {string: string}, {string: string}, string
  local ids: {string} = {}
  for id in pairs(items) do ids[#ids + 1] = id end
  table.sort(ids)
  if #ids == 0 then return {}, {}, "" end
  local argv: {string} = {"git", "rev-list", "--first-parent", "--parents"}
  for _, id in ipairs(ids) do argv[#argv + 1] = items[id].tip end
  local r, rerr = proc.run(argv, {cwd = s.root})
  if r == nil then return {}, {}, rerr end
  if not r.ok then return {}, {}, ("git rev-list failed: %s"):format(r.stderr) end
  local parent: {string: string} = {}
  local commits: {string} = {}
  for line in r.stdout:gmatch("([^\n]+)") do
    local commit, first_parent = line:match("^(%S+)%s+(%S+)")
    if commit == nil then commit = line:match("^(%S+)$") end
    if commit ~= nil then
      commits[#commits + 1] = commit
      parent[commit] = first_parent or ""
    end
  end
  local queries: {string} = {}
  for _, commit in ipairs(commits) do queries[#queries + 1] = commit .. ":meta" end
  local raw, berr = gitobj.cat_file_batch(s.root, queries)
  if raw == nil then return {}, {}, berr end
  local pointers: {string: string} = {}
  for _, commit in ipairs(commits) do
    local entry = raw[commit .. ":meta"]
    if entry ~= nil then
      pointers[commit] = itemtree.parse_meta(entry.content).claim_batch or ""
    end
  end
  return parent, pointers, ""
end

local function bridge_problem(it: ItemTip, row: claimbatch.Row,
    batch_sha: string, parent: {string: string}, pointers: {string: string}): string
  local commit, saw_tip = it.tip, false
  local seen: {string: boolean} = {}
  while commit ~= "" and not seen[commit] do
    seen[commit] = true
    if commit == row.item_tip then saw_tip = true end
    if parent[commit] == row.item_tip and pointers[commit] == batch_sha then
      return ""
    end
    commit = parent[commit] or ""
  end
  if not saw_tip then
    return ("tip %s does not descend from recorded item_tip %s")
    :format(it.tip:sub(1, 12), row.item_tip:sub(1, 12))
  end
  return ("has no first-parent claim bridge from recorded item_tip %s")
  :format(row.item_tip:sub(1, 12))
end

--- Validate each canonical batch object and both directions of its bridge
--- relation.  The raw pass deliberately runs before `gitread.list`, so a
--- broken pointer receives a precise fsck finding instead of only its normal
--- read refusal.
local function problems(s: store.Store): {string}
  local found, ferr = refs.for_each_ref(s.root,
    {"refs/heads/items", "refs/heads/ended", "refs/heads/claim-batches"})
  if found == nil then return {("could not inspect claim batches: %s"):format(ferr)} end
  local items = item_tips(s, found)
  local item_ids: {string} = {}
  local meta_queries: {string} = {}
  for id in pairs(items) do item_ids[#item_ids + 1] = id end
  table.sort(item_ids)
  for _, id in ipairs(item_ids) do meta_queries[#meta_queries + 1] = items[id].tip .. ":meta" end
  local meta, merr = gitobj.cat_file_batch(s.root, meta_queries)
  local out: {string} = {}
  if meta == nil then
    out[#out + 1] = ("could not read item claim pointers: %s"):format(merr)
    return out
  end
  for _, id in ipairs(item_ids) do
    local it = items[id]
    local entry = meta[it.tip .. ":meta"]
    if entry ~= nil then it.pointer = itemtree.parse_meta(entry.content).claim_batch or "" end
  end

  local canonical_by_id: {string: string} = {}
  local batches: {string: claimbatch.Batch} = {}
  local read_errors: {string: string} = {}
  local function read_batch(sha: string): claimbatch.Batch | nil, string
    local known = batches[sha]
    if known ~= nil then return known, "" end
    local prior = read_errors[sha]
    if prior ~= nil then return nil, prior end
    local batch, err = claimbatch.read(s.root, sha)
    if batch == nil then read_errors[sha] = err; return nil, err end
    batches[sha] = batch
    return batch, ""
  end
  for _, r in ipairs(found) do
    local name = r.refname:match("^refs/heads/claim%-batches/(.+)$")
    if name ~= nil then
      local batch, err = read_batch(r.sha)
      if batch == nil then
        out[#out + 1] = ("%s: malformed claim batch: %s"):format(r.refname, err)
      elseif batch.id ~= name then
        out[#out + 1] = ("%s: manifest names batch %s, not %s")
        :format(r.refname, batch.id, name)
      else
        canonical_by_id[name] = r.sha
      end
    end
  end
  for _, id in ipairs(item_ids) do
    local it = items[id]
    if it.pointer ~= "" then
      local batch, err = read_batch(it.pointer)
      if batch == nil then
        out[#out + 1] = ("%s: claim_batch %s does not resolve: %s")
        :format(id:sub(1, 8), it.pointer, err)
      else
        if canonical_by_id[batch.id] ~= it.pointer then
          out[#out + 1] = ("%s: claim_batch %s is orphaned; canonical "
            .. "refs/heads/claim-batches/%s does not name it")
          :format(id:sub(1, 8), it.pointer:sub(1, 12), batch.id)
        end
        local member: claimbatch.Row | nil = nil
        for _, row in ipairs(batch.rows) do if row.id == id then member = row; break end end
        if member == nil then
          out[#out + 1] = ("%s: claim batch %s does not contain its item row")
          :format(id:sub(1, 8), batch.id)
        end
      end
    end
  end
  if next(batches) == nil then return out end
  local parent, pointers, herr = history(s, items)
  if herr ~= "" then
    out[#out + 1] = ("could not inspect item claim history: %s"):format(herr)
    return out
  end
  local shas: {string} = {}
  for sha in pairs(batches) do shas[#shas + 1] = sha end
  table.sort(shas)
  for _, sha in ipairs(shas) do
    local batch = batches[sha]
    for _, row in ipairs(batch.rows) do
      local it = items[row.id]
      if it == nil then
        out[#out + 1] = ("claim batch %s: member %s has no canonical item history")
        :format(batch.id, row.id)
      else
        local bridge = bridge_problem(it, row, sha, parent, pointers)
        if bridge ~= "" then
          out[#out + 1] = ("claim batch %s: member %s %s")
          :format(batch.id, row.id:sub(1, 8), bridge)
        end
      end
    end
  end
  return out
end

local record gitfsck_claimbatch
  problems: function(s: store.Store): {string}
end

local M: gitfsck_claimbatch = {problems = problems}
return M
