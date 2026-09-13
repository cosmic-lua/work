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
    local got, err = boardread.list(s.root, s.state_head)
    if got == nil then return "REFUSED: cannot inspect claim: " .. err end
    s.state_reads["items/" .. it.id] = got.item_tree_by_id[it.id] or boardtree.ZERO_SHA
    s.state_reads["claims/" .. it.id] = got.claim_blob_by_id[it.id] or boardtree.ZERO_SHA
    local denial = claim.mutation_refusal(stateclaim.state(got.claims_by_id[it.id]),
      session or "", os.time(), force or false, why or "")
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
