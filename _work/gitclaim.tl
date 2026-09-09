--- Claim policy and Git bridges around immutable `_work.claimbatch` objects.
--- The existing item refs remain the write fence: every claimed member advances
--- through a first-parent bridge whose tree points at the one shared batch.
--- One ordinary prepared transaction publishes the append-only batch ref and
--- every item bridge atomically; this module performs no network operation.
local claim = require("_work.claim")
local claimbatch = require("_work.claimbatch")
local gitobj = require("_work.gitobj")
local gitread = require("_work.gitread")
local itemtree = require("_work.itemtree")
local prepared = require("_work.prepared")
local refs = require("_work.refs")

local enum Action
  "take"
  "renew"
  "drop"
end

local record Request
  root: string
  id: string
  source_ref: string
  target_ref: string
  remote: string
  batch: string
  caller: string
  action: Action
  product_base: string
  force: boolean
  why: string
  now: integer
end

local record Member
  id: string
  old_sha: string
  new_sha: string
  target_ref: string
  operation: string
  claim_root: string
  branch: string
  expires_at: integer
end

local record Prepared
  id: string
  batch: claimbatch.Batch
  transaction: prepared.Transaction
  members: {Member}
  deadline: integer
end

local record BatchResult
  prepared: Prepared | nil
  refused: {string: string}
end

local function target_item_ref(id: string, ended?: boolean): string
  return (ended and "refs/heads/ended/" or "refs/heads/items/") .. id
end

local function remote_item_ref(remote: string, id: string,
    ended?: boolean): string
  return ("refs/remotes/%s/%s/%s"):format(remote,
    ended and "ended" or "items", id)
end

local function batch_ref(id: string): string
  return "refs/heads/claim-batches/" .. id
end

local function state_for(root: string, batch_sha: string,
    id: string): claim.State | nil, string
  if batch_sha == "" then return nil, "" end
  return claimbatch.read_state(root, batch_sha, id)
end

local function refused(out: BatchResult): boolean
  return next(out.refused) ~= nil
end

--- Prepare one logical all-or-nothing set. Policy is evaluated completely
--- before objects are written, so a refused member leaves no publishable subset.
local function prepare_batch(requests: {Request}): BatchResult
  local out: BatchResult = {prepared = nil, refused = {}}
  if #requests == 0 then
    out.refused.batch = "a claim batch needs at least one item"
    return out
  end
  local first = requests[1]
  if first.now <= 0 then out.refused.batch = "now must be an epoch second"; return out end
  local seen: {string: boolean} = {}
  for _, req in ipairs(requests) do
    if req.root ~= first.root or req.remote ~= first.remote
    or req.batch ~= first.batch or req.caller ~= first.caller
    or req.action ~= first.action or req.now ~= first.now then
      out.refused.batch = "claim requests do not describe one batch"
    elseif seen[req.id] then
      out.refused[req.id] = "item occurs more than once in claim set"
    elseif req.target_ref ~= target_item_ref(req.id)
    and req.target_ref ~= target_item_ref(req.id, true) then
      out.refused[req.id] = "claim target does not match item id"
    end
    seen[req.id] = true
  end
  if refused(out) then return out end

  local loaded: {string: gitread.Loaded} = {}
  local rows: {claimbatch.Row} = {}
  local publish_by = 0
  for _, req in ipairs(requests) do
    local tip, terr = refs.read_ref(req.root, req.source_ref)
    if tip == nil then out.refused[req.id] = terr
    elseif tip == refs.ZERO_SHA then out.refused[req.id] = "no fetched item at " .. req.source_ref
    else
      local got, gerr = gitread.load(req.root, req.id, req.source_ref, tip,
        req.now)
      if got == nil then out.refused[req.id] = gerr else
        loaded[req.id] = got
        local current_batch = got.it.claim_batch or ""
        local st, serr = state_for(req.root, current_batch, req.id)
        if serr ~= "" then out.refused[req.id] = serr else
          local operation, holder = "", req.caller
          local base, root = "", ""
          local acquired, renewed, expires = req.now, req.now,
          req.now + claim.LEASE_S
          if req.action == "take" then
            local status = claim.status(st, req.now)
            if status == "future" then
              out.refused[req.id] = "claim timestamp is more than five minutes in the future"
            elseif status == "active" and st ~= nil then
              out.refused[req.id] = ("item is claimed by %s until %d")
              :format(st.holder, st.expires_at)
            else
              operation = "acquire"
              -- A new lease starts from the current target, even when a
              -- historical claim records a different product base.
              base = req.product_base
              if base == "" or #base ~= 40 or base:match("^[0-9a-f]+$") == nil then
                out.refused[req.id] = "product base must be a full commit id"
              end
            end
          elseif req.action == "renew" then
            local denial = claim.renew_refusal(st, req.caller, req.now)
            if denial ~= nil then out.refused[req.id] = denial elseif st ~= nil then
              operation, base, root = "renew", st.product_base, st.root
              acquired = st.acquired_at
              if publish_by == 0 or st.expires_at < publish_by then
                publish_by = st.expires_at
              end
            end
          else
            local denial = claim.drop_refusal(st, req.caller, req.now,
              req.force or false, req.why or "")
            if denial ~= nil then out.refused[req.id] = denial elseif st ~= nil then
              operation, holder, base, root = "drop", "", st.product_base, st.root
              acquired, renewed, expires = st.acquired_at, st.renewed_at, st.expires_at
            end
          end
          if operation ~= "" then
            rows[#rows + 1] = {id = req.id, item_tip = tip,
              operation = operation, holder = holder, product_base = base,
              root = root, acquired_at = acquired, renewed_at = renewed,
              expires_at = expires}
          end
        end
      end
    end
  end
  if refused(out) then return out end

  local batch, berr = claimbatch.create(first.root, {id = first.batch,
      caller = first.caller, remote = first.remote, action = first.action,
      created_at = first.now,
      publish_by = first.action == "drop" and 0
      or (publish_by ~= 0 and publish_by or first.now + claim.LEASE_S),
      why = first.why or "", rows = rows})
  if batch == nil then out.refused.batch = berr; return out end
  local updates: {prepared.Update} = {{ref = batch_ref(first.batch),
      expected = refs.ZERO_SHA, next = batch.commit}}
  local members: {Member} = {}
  local deadline = batch.publish_by
  for _, req in ipairs(requests) do
    local got = loaded[req.id]
    local row: claimbatch.Row = nil
    for _, candidate in ipairs(batch.rows) do
      if candidate.id == req.id then row = candidate; break end
    end
    if row == nil then out.refused.batch = "created batch lost a member"; return out end
    got.it.claim_batch = batch.commit
    local spec = gitread.read_spec(first.root, {row.item_tip})
    local tree, tree_err = itemtree.build_tree(first.root, got.it, spec, true)
    if tree == nil then out.refused[req.id] = tree_err; return out end
    local date = ("%d +0000"):format(first.now)
    local subject = first.action == "take"
    and ("take %s by %s"):format(req.id:sub(1, 8), first.caller)
    or ("claim %s %s by %s"):format(first.action,
      req.id:sub(1, 8), first.caller)
    local bridge, cerr = gitobj.commit_tree(first.root, {tree = tree,
        parents = {row.item_tip},
        message = ("%s\n\nClaim-Batch: %s"):format(subject, batch.commit),
        author_name = first.caller, author_email = first.caller .. "@board",
        author_date = date, committer_name = "gitboard",
        committer_email = "gitboard@board", committer_date = date,
        op = "claim-bridge"})
    if bridge == nil then out.refused[req.id] = cerr; return out end
    updates[#updates + 1] = {ref = req.target_ref, expected = row.item_tip,
      next = bridge}
    local root = row.root
    members[#members + 1] = {id = req.id, old_sha = row.item_tip,
      new_sha = bridge, target_ref = req.target_ref, operation = row.operation,
      claim_root = root, branch = root ~= "" and claim.branch(req.id, root) or "",
      expires_at = row.expires_at}
  end
  local tx, perr = prepared.prepare(first.root, updates,
    "prepare atomic claim batch " .. first.batch)
  if tx == nil then out.refused.batch = perr; return out end
  out.prepared = {id = first.batch, batch = batch, transaction = tx,
    members = members, deadline = deadline}
  return out
end

local function push_argv(p: Prepared, remote: string,
    now?: integer): {string} | nil, string
  if p.deadline > 0 and (now or os.time()) >= p.deadline then
    return nil, "prepared claim batch expired before publication"
  end
  return prepared.push_argv(p.transaction, remote), ""
end

local function from_transaction(root: string,
    tx: prepared.Transaction): Prepared | nil, string
  local batch_sha, batch_id = "", ""
  for _, update in ipairs(tx.updates) do
    local id = update.ref:match("^refs/heads/claim%-batches/(.+)$")
    if id ~= nil then
      if batch_sha ~= "" then return nil, "transaction has multiple claim batches" end
      batch_sha, batch_id = update.next, id
    end
  end
  if batch_sha == "" then return nil, "not a claim batch transaction" end
  local batch, err = claimbatch.read(root, batch_sha)
  if batch == nil then return nil, err end
  if batch.id ~= batch_id then return nil, "claim batch ref and object disagree" end
  local members: {Member} = {}
  local deadline = batch.publish_by
  for _, row in ipairs(batch.rows) do
    local update: prepared.Update = nil
    for _, candidate in ipairs(tx.updates) do
      if candidate.ref == target_item_ref(row.id)
      or candidate.ref == target_item_ref(row.id, true) then update = candidate; break end
    end
    if update == nil or update.expected ~= row.item_tip then
      return nil, "claim transaction has no matching item bridge for " .. row.id
    end
    members[#members + 1] = {id = row.id, old_sha = row.item_tip,
      new_sha = update.next, target_ref = update.ref, operation = row.operation,
      claim_root = row.root,
      branch = row.root ~= "" and claim.branch(row.id, row.root) or "",
      expires_at = row.expires_at}
  end
  return {id = batch.id, batch = batch, transaction = tx,
    members = members, deadline = deadline}, ""
end

local function list_prepared(root: string, _remote: string): {Prepared} | nil, string
  local transactions, err = prepared.list(root)
  if transactions == nil then return nil, err end
  local out: {Prepared} = {}
  for _, tx in ipairs(transactions) do
    local has_batch = false
    for _, update in ipairs(tx.updates) do
      if update.ref:match("^refs/heads/claim%-batches/") then has_batch = true end
    end
    if has_batch then
      local p, perr = from_transaction(root, tx)
      if p == nil then return nil, perr end
      out[#out + 1] = p
    end
  end
  return out, ""
end

local record gitclaim
  type Action = Action
  type Request = Request
  type Member = Member
  type Prepared = Prepared
  type BatchResult = BatchResult
  target_item_ref: function(id: string, ended?: boolean): string
  remote_item_ref: function(remote: string, id: string, ended?: boolean): string
  batch_ref: function(id: string): string
  prepare_batch: function(requests: {Request}): BatchResult
  push_argv: function(p: Prepared, remote: string,
  now?: integer): {string} | nil, string
  from_transaction: function(root: string,
  tx: prepared.Transaction): Prepared | nil, string
  list_prepared: function(root: string, remote: string): {Prepared} | nil, string
end

local M: gitclaim = {
  target_item_ref = target_item_ref,
  remote_item_ref = remote_item_ref,
  batch_ref = batch_ref,
  prepare_batch = prepare_batch,
  push_argv = push_argv,
  from_transaction = from_transaction,
  list_prepared = list_prepared,
}

return M
