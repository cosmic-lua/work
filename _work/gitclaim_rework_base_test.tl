#!/usr/bin/env cosmic
-- A REWORK claim — an item already carrying a commit handover judged
-- `request changes` — continues from the handover, not from `main`, so it
-- must never be refused by either of the two guards that exist to protect
-- an ordinary claim: the stale-target-branch guard (the handover is
-- immutable board state, not a local ref that can go stale) and the
-- handover-ancestry guard (the handover is by definition what the rework
-- continues from; asking `main` to still reach it is exactly backwards for
-- this case). `main` moving past the handover is routine, since other
-- items land while this one is in review.
local check = require("cosmic.check")
local child = require("cosmic.child")
local boardread = require("_work.boardread")
local boardtree = require("_work.boardtree")
local flow = require("_work.commit_flow_fixture")
local store = require("_work.store")
local verdict = require("_work.gitverdict")

local function git(root: string, args: {string}): string
  local argv: {string} = {"git"}
  for _, value in ipairs(args) do argv[#argv + 1] = value end
  local r = check.must(child.run(argv, {cwd = root}))
  assert(r.ok, "git " .. table.concat(args, " ") .. " failed: " .. r.stderr)
  return (r.stdout:gsub("%s+$", ""))
end

--- Move the product repository's `main` without touching its working tree —
--- the claim only ever consults the ref, never the checkout.
local function move_main(root: string, sha: string)
  git(root, {"branch", "-f", "main", sha})
end

local function fact(s: store.Store, id: string): boardtree.Claim
  return check.must(check.must(boardread.load(s.root, s.state_head, id)).claim)
end

--- A builder claim, handed over, dropped, then reviewed and judged with the
--- given verdict — the shape a rework (or, with a different verdict, an
--- ordinary judged item) takes by the time `main` has moved on and someone
--- re-claims it.
local function judged(name: string, kind: string): store.Store, string,
  flow.Product
  local s, id, p = flow.fresh(name)
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  assert(flow.handover(s, id, flow.BUILDER, p, p.head) == 0)
  assert(flow.claim(s, id, flow.BUILDER, p, "drop") == 0)
  assert(flow.claim(s, id, flow.REVIEWER, p) == 0)
  assert(verdict.cmd_verdict_commit(s, id, kind, p.head, flow.REVIEWER,
      false, "", p.root) == 0)
  assert(flow.claim(s, id, flow.REVIEWER, p, "drop") == 0)
  return s, id, p
end

local function test_rework_reclaim_uses_the_handover_as_base()
  local s, id, p = judged("rework-base-reclaim", "request changes")
  -- `main` advances to a sibling of the handover, off the same original
  -- base, unrelated to it — exactly the shape "other items land while this
  -- one is in review" takes, and exactly what deadlocked before this
  -- change: `main` can no longer reach the handover.
  move_main(p.root, p.mismatch)
  local rc = flow.claim(s, id, flow.BUILDER, p)
  assert(rc == 0,
    "a rework re-claim must use the handover as its base, not the stale " ..
    "local main tip")
  assert(fact(s, id).product_base == p.head,
    "the rework claim must record the handover itself as its product base")
  local it = check.must(store.load(s, id))
  assert(it.claim == flow.BUILDER and it.handover_head == p.head)
end
test_rework_reclaim_uses_the_handover_as_base()

local function test_the_same_main_advance_without_request_changes_still_refuses()
  -- Same shape, but judged `accept` rather than `request changes`: the item
  -- still carries a handover_head, so this isolates the verdict half of the
  -- escape hatch's condition, not merely whether one is present.
  local s, id, p = judged("rework-base-not-rework", "accept")
  move_main(p.root, p.mismatch)
  local rc = flow.claim(s, id, flow.REVIEWER, p)
  assert(rc ~= 0,
    "the escape hatch must be scoped to a request-changes rework — an " ..
    "accepted item's re-claim must still refuse a main that cannot reach " ..
    "its handover")
  local it = check.must(store.load(s, id))
  assert((it.claim or "") == "",
    "the refused claim must not be recorded")
end
test_the_same_main_advance_without_request_changes_still_refuses()

local function test_rework_reclaim_skips_the_stale_tracking_check()
  -- The other half of the escape hatch: a rework re-claim must not be
  -- refused for a LOCAL main that is behind its own tracking ref either —
  -- the handover is used directly, without ever consulting `main` at all.
  local s, id, p = judged("rework-base-stale-tracking", "request changes")
  -- Give `main` a configured remote whose tip has moved past what the
  -- local branch holds, the exact shape `_work/gitclaim_stale_base_test.tl`
  -- builds for the ordinary-claim guard this case must NOT trip.
  local remote_dir = p.root .. "-remote"
  git(p.root, {"clone", "-q", "--bare", p.root, remote_dir})
  git(remote_dir, {"update-ref", "refs/heads/main", p.mismatch})
  git(p.root, {"remote", "add", "origin", remote_dir})
  git(p.root, {"fetch", "-q", "origin"})
  git(p.root, {"branch", "-q", "--set-upstream-to=origin/main", "main"})
  local rc = flow.claim(s, id, flow.BUILDER, p)
  assert(rc == 0,
    "a rework re-claim must skip the behind-tracking-ref check: the " ..
    "handover is used directly, not the local main tip it would refuse")
  assert(fact(s, id).product_base == p.head,
    "the rework claim must still record the handover, not the mismatched " ..
    "remote tip")
end
test_rework_reclaim_skips_the_stale_tracking_check()
