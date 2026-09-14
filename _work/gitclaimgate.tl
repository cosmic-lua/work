--- Whole-item claim enforcement against the invocation's immutable native head.
local claim = require("_work.claim")
local stateclaim = require("_work.stateclaim")
local item = require("_work.item")
local refs = require("_work.refs")
local store = require("_work.store")

--- Fence both item and claim paths before deciding whether the caller may edit.
--- The projection refreshes at lease expiry, even while the head stays fixed.
local function mutation_refusal(s: store.Store, it: item.Item,
    session: string, force: boolean, why: string): string | nil
  local view, err = store.view(s)
  if view == nil then return "REFUSED: cannot inspect claim: " .. err end
  local item_path, claim_path = "items/" .. it.id, "claims/" .. it.id
  local tree = view.item_tree_by_id[it.id] or refs.ZERO_SHA
  local blob = view.claim_blob_by_id[it.id] or refs.ZERO_SHA
  s.state_paths[item_path], s.state_paths[claim_path] = tree, blob
  s.state_reads[item_path], s.state_reads[claim_path] = tree, blob
  if tree == refs.ZERO_SHA and blob ~= refs.ZERO_SHA then
    return "REFUSED: absent item has a canonical claim"
  end
  local refusal = claim.mutation_refusal(stateclaim.state(view.claims_by_id[it.id]),
    session or "", os.time(), force or false, why or "")
  return refusal ~= nil and "REFUSED: " .. refusal or nil
end
return {mutation_refusal = mutation_refusal}
