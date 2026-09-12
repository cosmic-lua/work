#!/usr/bin/env cosmic
-- A review claim over an item that already carries a recorded handover must
-- never silently capture a local product base the handover cannot descend
-- from — the shape a claim takes once the target branch has advanced past an
-- unrelated later commit since the handover was recorded. `verdict`'s own
-- ancestry check would otherwise refuse much later, with no explanation.
local check = require("cosmic.check")
local child = require("cosmic.child")
local claimbatch = require("_work.claimbatch")
local flow = require("_work.commit_flow_fixture")
local store = require("_work.store")

local function git(root: string, args: {string}): string
  local argv: {string} = {"git"}
  for _, value in ipairs(args) do argv[#argv + 1] = value end
  local r = check.must(child.run(argv, {cwd = root}))
  assert(r.ok, "git " .. table.concat(args, " ") .. " failed: " .. r.stderr)
  return (r.stdout:gsub("%s+$", ""))
end

--- Move the product repository's `main` without touching its working tree —
--- the review claim only ever consults the ref, never the checkout.
local function move_main(root: string, sha: string)
  git(root, {"branch", "-f", "main", sha})
end

local function fact(s: store.Store, id: string): claimbatch.Fact
  local it = check.must(store.load(s, id))
  return check.must(claimbatch.read_fact(s.root, it.claim_batch or "", id))
end

--- An item handed over, then dropped by its builder — an expired original
--- claim, held under a since-gone session, takes exactly this shape by the
--- time a reviewer's fresh `claim` reaches it.
local function handed_over_and_released(name: string): store.Store, string,
  flow.Product
  local s, id, p = flow.fresh(name)
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  assert(flow.handover(s, id, flow.BUILDER, p, p.head) == 0)
  assert(flow.claim(s, id, flow.BUILDER, p, "drop") == 0)
  return s, id, p
end

local function test_a_base_that_cannot_reach_the_handover_refuses()
  local s, id, p = handed_over_and_released("handover-ancestry-refuse")
  -- `main` advances to a sibling of the handover, off the same original
  -- base, unrelated to it — the shape an intervening, unrelated merge takes.
  move_main(p.root, p.mismatch)
  local rc = flow.claim(s, id, flow.REVIEWER, p)
  assert(rc ~= 0,
    "a review claim whose base cannot reach the handover must not succeed")
  local it = check.must(store.load(s, id))
  assert((it.claim or "") == "",
    "the refused claim must not be recorded")
  assert(it.handover_head == p.head,
    "a refused claim must never disturb the recorded handover")
end
test_a_base_that_cannot_reach_the_handover_refuses()

local function test_a_base_the_handover_still_descends_from_claims()
  local s, id, p = handed_over_and_released("handover-ancestry-claim")
  -- The reviewer's checkout is positioned exactly at the handover — the
  -- shape a fetch/checkout at-or-before it takes.
  move_main(p.root, p.head)
  local rc = flow.claim(s, id, flow.REVIEWER, p)
  assert(rc == 0,
    "a base the handover still descends from must claim normally")
  assert(fact(s, id).product_base == p.head)
end
test_a_base_the_handover_still_descends_from_claims()

local function test_an_item_with_no_handover_is_unaffected()
  local s, id, p = flow.fresh("handover-ancestry-none")
  move_main(p.root, p.mismatch)
  local rc = flow.claim(s, id, flow.BUILDER, p)
  assert(rc == 0,
    "an item with no recorded handover has nothing for this guard to check")
end
test_an_item_with_no_handover_is_unaffected()
