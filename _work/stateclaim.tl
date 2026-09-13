--- Native claims: policy evaluated for the entire set before a transition exists.
local boardread = require("_work.boardread")
local boardtree = require("_work.boardtree")
local claim = require("_work.claim")
local tx = require("_work.statetransaction")
local enum Action
  "take"
  "renew"
  "drop"
end
local record Request
  id: string
  product_base: string
end
local record Member
  id: string
  claim_root: string
  branch: string
  expires_at: integer
  operation: string
end
local record Result
  changes: {tx.Change}
  dependencies: {tx.Dependency}
  members: {Member}
  refused: {string: string}
  publish_by: integer
end
--- One recorded lease as the shared claim logic sees it. `root` carries the
--- blob's `id`, which is the minted identity for a native acquisition and the
--- acquisition commit for an imported one; `control` is empty because the
--- deadline it fed on format 5 is `expires_at`, which the blob carries itself.
--- @param value boardtree.Claim | nil The recorded lease, nil when none
--- @return claim.State | nil The lease in the shared shape, nil when none
local function state(value: boardtree.Claim | nil): claim.State | nil
  if value == nil then return nil end
  return {holder = value.holder, root = value.id, control = "", acquired_at = value.acquired_at,
    renewed_at = value.renewed_at, expires_at = value.expires_at, product_base = value.product_base}
end
--- Everything one claim, renew, drop or take needs to become a transition,
--- decided against one immutable head: the `claims/<id>` writes, the two paths
--- every member fences, the earliest member's expiry as `publish_by`, and the
--- per-member identity and work branch to report. A refusal anywhere empties
--- the whole result: a claim batch is atomic, so no member lands alone.
--- @param root string The repository holding `head`
--- @param head string The exact commit to decide against
--- @param requests {Request} One entry per member, with its product base
--- @param action Action take, renew or drop
--- @param caller string The session asking
--- @param now integer The instant leases are judged at
--- @param force boolean Whether to supersede another session's live lease
--- @param why string The reason a forced acquisition carries
--- @return Result The changes, fences, deadline and members, or the refusals
local function prepare(root: string, head: string, requests: {Request}, action: Action,
    caller: string, now: integer, force: boolean, why: string): Result
  local out: Result = {changes = {}, dependencies = {}, members = {}, refused = {}, publish_by = 0}
  if #requests == 0 or now <= 0 then out.refused.batch = "claim needs members and a valid clock"; return out end
  local view, err = boardread.list(root, head, now)
  if view == nil then out.refused.batch = err; return out end
  local seen: {string: boolean} = {}
  for _, req in ipairs(requests) do
    local old = view.claims_by_id[req.id]
    local st = state(old)
    local denial: string | nil
    local held = false
    local operation = action == "take" and "acquire" or action
    local next_claim: boardtree.Claim | nil = nil
    if seen[req.id] then denial = "item occurs more than once in claim set"
    elseif view.items_by_id[req.id] == nil then denial = "no such item"
    elseif action == "take" then
      denial, held = claim.take_refusal(st, caller, now, force, why)
      if denial == nil then
        if held then next_claim = old; operation = "hold"
        elseif #req.product_base ~= 40 or not req.product_base:match("^[0-9a-f]+$") then
          denial = "product base must be a full commit id"
        else
          operation = claim.status(st, now) == "active" and "force" or "acquire"
          next_claim = {id = boardtree.mint_claim_id(), holder = caller,
            acquired_at = now, renewed_at = now, expires_at = now + claim.LEASE_S,
            product_base = req.product_base}
        end
      end
    elseif action == "renew" then
      denial = claim.renew_refusal(st, caller, now)
      if denial == nil and old ~= nil then
        next_claim = {id = old.id, holder = old.holder, acquired_at = old.acquired_at,
          renewed_at = now, expires_at = now + claim.LEASE_S, product_base = old.product_base}
      end
    else denial = claim.drop_refusal(st, caller, now, force, why) end
    seen[req.id] = true
    if denial ~= nil then out.refused[req.id] = denial
    else
      local path = "claims/" .. req.id
      local content = ""
      if next_claim ~= nil then
        local encoded, eerr = boardtree.encode_claim(next_claim)
        if encoded == nil then out.refused[req.id] = eerr else content = encoded end
      end
      out.dependencies[#out.dependencies + 1] = {path = "items/" .. req.id, id = view.item_tree_by_id[req.id]}
      out.dependencies[#out.dependencies + 1] = {path = path, id = view.claim_blob_by_id[req.id] or boardtree.ZERO_SHA}
      local unchanged_renew = action == "renew" and old ~= nil
      and next_claim ~= nil and old.renewed_at == next_claim.renewed_at
      and old.expires_at == next_claim.expires_at
      if not held and not unchanged_renew then
        out.changes[#out.changes + 1] = {path = path, mode = "100644", content = content, delete = action == "drop"}
      end
      local identity = next_claim ~= nil and next_claim.id or old ~= nil and old.id or ""
      local expires = next_claim ~= nil and next_claim.expires_at or old ~= nil and old.expires_at or 0
      local deadline = action == "drop" and 0 or action == "renew" and old ~= nil and old.expires_at or expires
      if deadline > 0 and (out.publish_by == 0 or deadline < out.publish_by) then out.publish_by = deadline end
      out.members[#out.members + 1] = {id = req.id, claim_root = identity,
        branch = claim.branch(req.id, identity), expires_at = expires, operation = operation}
    end
  end
  if next(out.refused) ~= nil then out.changes = {}; out.dependencies = {}; out.members = {} end
  return out
end
--- Refresh reports current authority independently of historical publication proof.
local function authority(root: string, head: string): string | nil, string
  local view, err = boardread.list(root, head)
  if view == nil then return nil, err end
  local ids: {string} = {}
  for id in pairs(view.claims_by_id) do ids[#ids + 1] = id end
  table.sort(ids)
  local lines: {string} = {}
  local now = os.time()
  for _, id in ipairs(ids) do
    local value = view.claims_by_id[id]
    lines[#lines + 1] = ("current-claim %s status=%s holder=%s claim=%s branch=%s expires=%d")
    :format(id, claim.status(state(value), now), value.holder, value.id,
      claim.branch(id, value.id), value.expires_at)
  end
  return #lines > 0 and table.concat(lines, "\n") or "current-claims=0", ""
end
local record Module
  type Action = Action
  type Request = Request
  type Member = Member
  type Result = Result
  authority: function(string, string): string | nil, string
  state: function(boardtree.Claim | nil): claim.State | nil
  prepare: function(string, string, {Request}, Action, string, integer, boolean, string): Result
end
local M: Module = {state = state, prepare = prepare, authority = authority}
return M
