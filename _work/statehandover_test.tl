--- Handover records existing work in one exact full-board snapshot. It neither
--- acquires a claim nor pulls capacity.
local check = require("cosmic.check")
local child = require("cosmic.child")
local flow = require("_work.commit_flow_fixture")
local snapshot = require("_work.snapshot")
local store = require("_work.store")

local function test_handover_fences_item_and_claim_without_pull_gate()
  local s, id, product = flow.fresh("native-handover-fences")
  assert(flow.claim(s, id, flow.BUILDER, product) == 0)
  local base = s.state_head
  assert(flow.handover(s, id, flow.BUILDER, product, product.head) == 0)
  local identity = check.must(snapshot.commit_identity(s.root, s.state_head))
  assert(identity.parent == base,
    "handover publishes one snapshot bound to the whole prior head")
  local claims = check.must(child.run(
      {"git", "diff", "--quiet", base, s.state_head, "--", "claims"},
      {cwd = s.root}))
  assert(claims.ok, "handover leaves claim blobs unchanged")
  local it = check.must(store.load(s, id))
  assert(it.claim == flow.BUILDER and it.handover_head == product.head,
    "the proposal preserves acquisition and records verified work")
end
