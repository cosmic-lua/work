--- Handover records existing work; it neither acquires a claim nor pulls capacity.
local check = require("cosmic.check")
local flow = require("_work.commit_flow_fixture")
local draft = require("_work.gitdraft")
local staging = require("_work.statestaging")
local store = require("_work.store")

local function test_handover_fences_item_and_claim_without_pull_gate()
  local s, id, product = flow.fresh("native-handover-fences")
  assert(flow.claim(s, id, flow.BUILDER, product) == 0)
  assert(store.close(s))
  local saved = check.must(draft.begin(s.root))
  assert(draft.activate(s.root, saved))
  s = check.must(store.open(s.root))
  assert(flow.handover(s, id, flow.BUILDER, product, product.head) == 0)
  draft.deactivate(s.root)
  local receipt = check.must(staging.load(s.root, saved.staging_ref))
  assert(#receipt.transitions == 1)
  local transition = receipt.transitions[1]
  assert(not transition.bounded, "handover must not re-run the retired pull gate")
  local fenced: {string: boolean} = {}
  for _, dependency in ipairs(transition.dependencies) do fenced[dependency.path] = true end
  assert(fenced["items/" .. id] and fenced["claims/" .. id],
    "handover must preserve whole-item authority")
  for _, change in ipairs(transition.changes) do
    assert(change.path:sub(1, 7) ~= "claims/", "handover must preserve the acquisition")
  end
  assert(store.close(s))
end
