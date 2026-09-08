--- Whole-item claim enforcement shared by every mutation path.
local claim = require("_work.claim")
local gitclaim = require("_work.gitclaim")
local item = require("_work.item")
local store = require("_work.store")

--- The lease clock comes from the newest claim-control commit, not the item
--- tip: ordinary work must never renew a claim as a side effect. Expiry makes
--- a competing CAS legal; it does not rewrite or clear the item.
local function mutation_refusal(s: store.Store, it: item.Item,
    session: string, force: boolean, why: string): string | nil
  local before = s.leased_item[it.id]
  local tip = s.leased_sha[it.id] or ""
  if before == nil or tip == "" or (before.claim or "") == "" then return nil end
  local st, err = gitclaim.read_state(s.root, tip, before.claim or "",
    before.claim_base or "")
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
