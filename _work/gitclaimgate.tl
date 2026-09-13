--- Whole-item claim enforcement shared by every mutation path.
local claim = require("_work.claim")
local claimbatch = require("_work.claimbatch")
local boardread = require("_work.boardread")
local boardtree = require("_work.boardtree")
local stateclaim = require("_work.stateclaim")
local item = require("_work.item")
local store = require("_work.store")

--- The lease clock comes from the newest claim-control commit, not the item
--- tip: ordinary work must never renew a claim as a side effect. Expiry makes
--- a competing CAS legal; it does not rewrite or clear the item.
local function mutation_refusal(s: store.Store, it: item.Item,
    session: string, force: boolean, why: string): string | nil
  if (s.state_head or "") ~= "" then
    local before = s.leased_item[it.id]
    local item_path, claim_path = "items/" .. it.id, "claims/" .. it.id
    local known_item, known_claim = s.state_paths[item_path], s.state_paths[claim_path]
    if before ~= nil and known_item ~= nil and known_claim ~= nil then
      -- Reading the loaded snapshot to decide is reading it: fence both paths.
      s.state_reads[item_path], s.state_reads[claim_path] = known_item, known_claim
      local holder = before.claim or ""
      if holder == "" or holder == (session or "") then return nil end
      if not (force or false) then return "REFUSED: item is frozen by " .. holder end
      if (why or ""):match("^%s*$") then return "REFUSED: forced mutation requires --why" end
      return nil
    end
    -- A freshly minted item has no loaded snapshot. Prove BOTH canonical
    -- paths absent and record the zero fences; the argument alone is never
    -- evidence that an id is new.
    local item_oid, ierr = boardtree.path_id(s.root, s.state_head, item_path)
    if item_oid == nil then return "REFUSED: cannot inspect claim: " .. ierr end
    local claim_oid, cerr = boardtree.path_id(s.root, s.state_head, claim_path)
    if claim_oid == nil then return "REFUSED: cannot inspect claim: " .. cerr end
    s.state_paths[item_path], s.state_paths[claim_path] = item_oid, claim_oid
    s.state_reads[item_path], s.state_reads[claim_path] = item_oid, claim_oid
    if item_oid == boardtree.ZERO_SHA then
      if claim_oid ~= boardtree.ZERO_SHA then
        return "REFUSED: absent item has a canonical claim"
      end
      return nil
    end
    -- A caller that bypassed list but names an existing item still receives
    -- the full exact canonical claim check.
    local got, err = boardread.load(s.root, s.state_head, it.id)
    if got == nil then return "REFUSED: cannot inspect claim: " .. err end
    s.state_paths[item_path], s.state_paths[claim_path] = got.tree, got.claim_blob
    s.state_reads[item_path], s.state_reads[claim_path] = got.tree, got.claim_blob
    local denial = claim.mutation_refusal(stateclaim.state(got.claim), session or "",
      os.time(), force or false, why or "")
    return denial ~= nil and "REFUSED: " .. denial or nil
  end
  local before = s.leased_item[it.id]
  if before == nil or (before.claim_batch or "") == "" then return nil end
  local pointer = before.claim_batch or ""
  if pointer == "" then return "REFUSED: active claim has no batch pointer" end
  local st, err = claimbatch.read_state(s.root, pointer, it.id)
  if err ~= "" then return "REFUSED: cannot inspect claim: " .. err end
  local refusal = claim.mutation_refusal(st, session or "", os.time(),
    force or false, why or "")
  if refusal ~= nil then return "REFUSED: " .. refusal end
  return nil
end

local record gitclaimgate
  mutation_refusal: function(s: store.Store, it: item.Item,
  session: string, force: boolean, why: string): string
end

local M: gitclaimgate = {mutation_refusal = mutation_refusal}
return M
