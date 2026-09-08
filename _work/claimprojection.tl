--- Project durable claim-batch pointers into transient item workflow fields.
--- One immutable batch is decoded once even when an atomic acquisition points
--- many item bridges at it. Item history never supplies live claim facts.
local claim = require("_work.claim")
local claimbatch = require("_work.claimbatch")
local item = require("_work.item")

local function one(it: item.Item, batch: claimbatch.Batch,
    now: integer): boolean, string
  local row: claimbatch.Row | nil = nil
  for _, candidate in ipairs(batch.rows) do
    if candidate.id == it.id then row = candidate break end
  end
  if row == nil then
    return false, ("claim batch %s does not contain item %s")
    :format(batch.commit, it.id)
  end
  if row.holder == "" then
    it.claim, it.claim_base = "", row.product_base
    return true, ""
  end
  local root = row.root
  if root == "" and (row.operation == "acquire" or row.operation == "force") then
    root = batch.commit
  end
  local st: claim.State = {holder = row.holder, root = root,
    control = batch.commit, acquired_at = row.acquired_at,
    renewed_at = row.renewed_at, expires_at = row.expires_at,
    product_base = row.product_base}
  local status = claim.status(st, now)
  if status == "future" then
    return false, ("claim batch %s for %s is more than five minutes in the future")
    :format(batch.commit, it.id)
  end
  if status == "active" then
    it.claim, it.claim_base = st.holder, st.product_base
  else
    it.claim, it.claim_base = "", st.product_base
  end
  return true, ""
end

local function apply(root: string, items: {item.Item},
    now: integer): boolean, string
  local batches: {string: claimbatch.Batch} = {}
  for _, it in ipairs(items) do
    local pointer = it.claim_batch or ""
    if pointer ~= "" then
      local batch = batches[pointer]
      if batch == nil then
        local loaded, err = claimbatch.read(root, pointer)
        if loaded == nil then return false, err end
        batch = loaded
        batches[pointer] = loaded
      end
      local ok, err = one(it, batch, now)
      if not ok then return false, err end
    else
      it.claim, it.claim_base = "", ""
    end
  end
  return true, ""
end

local record claimprojection
  apply: function(root: string, items: {item.Item}, now: integer): boolean, string
end

local M: claimprojection = {apply = apply}

return M
