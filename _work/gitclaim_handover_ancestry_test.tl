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

--- The refusal's own suggested recovery, followed exactly, end to end: not
--- `gitboard worktree ID --review` (which needs the very claim this refusal
--- withheld, and so can never satisfy its own precondition), but
--- repositioning the local product repo's own branch to (or behind) the
--- recorded handover, then retrying claim against that same repo. A wrong
--- suggested remedy could ship with green CI as long as no test actually
--- walked it end to end — this one does.
local function test_the_suggested_recovery_actually_results_in_a_claim()
  local s, id, p = handed_over_and_released("handover-ancestry-recover")
  -- Reproduce the exact refused state this item exists to guard against,
  -- with `main` itself checked out in the product repo — the realistic (in
  -- fact default) state, not `build_product`'s own orphan-branch escape
  -- hatch (it leaves `unrelated` checked out). `git branch -f` cannot move
  -- a branch that is currently checked out, so a test that never checks out
  -- `main` here would pass even if the refusal's suggested command failed
  -- in the one case that actually matters.
  move_main(p.root, p.mismatch)
  git(p.root, {"checkout", "-q", "main"})
  local refused_rc = flow.claim(s, id, flow.REVIEWER, p)
  assert(refused_rc ~= 0,
    "must reproduce the refusal before exercising its suggested recovery")
  assert((check.must(store.load(s, id)).claim or "") == "",
    "the refused attempt must not have left a claim to build the recovery on")
  -- Follow the refusal's own suggested recovery, literally: `git update-ref
  -- refs/heads/main <handover>` repositions the local product repo's branch
  -- to the recorded handover directly, without touching the working tree,
  -- so it succeeds even with `main` checked out — unlike `git branch -f`,
  -- which git itself refuses in exactly this state ("cannot force update
  -- the branch ... used by worktree"). Then retry `claim --repo-dir`
  -- against that same repo — `flow.claim` always passes `p.root` as
  -- `--repo-dir`.
  git(p.root, {"update-ref", "refs/heads/main", p.head})
  local recovered_rc = flow.claim(s, id, flow.REVIEWER, p)
  assert(recovered_rc == 0,
    "the refusal's suggested recovery must actually result in a successful claim")
  assert(fact(s, id).product_base == p.head,
    "the recovered claim must capture the repositioned base, not the earlier mismatch")
end
test_the_suggested_recovery_actually_results_in_a_claim()
