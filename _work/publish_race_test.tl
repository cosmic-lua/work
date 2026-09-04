#!/usr/bin/env cosmic
-- The lost-race contract end to end, through real verbs: a mutation
-- whose guards were decided against pre-race state is never replayed
-- onto the merged board. The two shapes that used to slip through a
-- clean rebase — reciprocal blocks landing a cycle, and the last two
-- children of one container closing at once with nobody re-phasing
-- the parent — are refused with LOST_RACE, and the RE-RUN, deciding
-- afresh against the merged state, does the right thing the stale
-- run could not see.

local check = require("cosmic.check")
local fixture = require("_work.fixture")
local flow = require("_work.flow")
local gitboard = require("_work.gitboard")
local graph = require("_work.gitgraph")
local health = require("_work.health")
local item = require("_work.item")
local publish = require("_work.publish")
local store = require("_work.store")
local verbs = require("_work.gitverbs")

local init_shared = fixture.init_shared
local file_item = fixture.file_item

-- Reciprocal `block` from two checkouts used to merge cleanly and
-- land a cycle no verb's own check ever saw, back when a single
-- shared branch meant EVERY mutation contended with every other. Each
-- side's edge now lives on its own item's ref (x's block writes only
-- x's ref, y's only y's), so nothing puts two DIFFERENT items'
-- blocks in each other's way UNLESS blocking is bounded — which the
-- add path is, exactly because `flow.waits_on`'s cycle check is a
-- whole-board read the same way the doing bound's is: it advances and
-- leases `refs/heads/board/seq`, so the second, stale block is the one that
-- loses that lease and is refused with LOST_RACE. Its re-run — reading
-- the winner's edge — refuses as the deadlock it is. No cycle at any
-- point.
local function test_a_lost_block_race_cannot_land_a_cycle()
  local a, b = init_shared("race-block")
  local x = file_item(a, "x, the one that waits", "")
  local y = file_item(a, "y, the one it waits on", "")
  assert(publish.sync(b))

  assert(graph.cmd_block(a, x, y, false, "x needs y's contract") == 0)
  -- b's read predates a's edge, exactly the reciprocal-block race.
  assert(graph.cmd_block(b, y, x, false, "y needs x's contract") ~= 0,
    "the losing block is refused, not replayed")
  local after = check.must(store.list(b))
  assert(#health.blocker_cycle_problems(after) == 0,
    "no cycle landed anywhere")
  -- The re-run decides against the merged board: the edge would
  -- deadlock both, and the verb's own guard says so.
  assert(graph.cmd_block(b, y, x, false, "y needs x's contract") ~= 0,
    "the re-run meets the cycle guard")
  assert(#(check.must(store.load(b, y)).blocked_by or {}) == 0,
    "and writes no edge")
  assert(#(check.must(store.load(b, x)).blocked_by or {}) == 1,
    "the winner's edge stands alone")
end

-- Concurrent `done` of a container's last two children, each read as
-- still open by the OTHER session: under a single shared branch this
-- used to race — the loser's stale run could not see the parent
-- becoming workable, and the miss used to merge cleanly. `done` is
-- unbounded and each child ends on its OWN ref (`c1`'s commit never
-- touches `c2`'s), so under the ref layout there is no race to lose
-- at all: both closes land independently, and the parent's role —
-- DERIVED, never stored — reads as workable again the moment both
-- children are read together, with nothing to have been lost.
local function test_concurrent_done_of_the_last_two_children_both_land()
  local a, b = init_shared("race-done")
  local root = file_item(a, "an outcome", "")
  local parent = file_item(a, "a slice being decomposed", root)
  local c1 = file_item(a, "the first child", parent)
  local c2 = file_item(a, "the second child", parent)
  assert(publish.sync(b))

  assert(verbs.cmd_done(a, c1, "completed", false, "") == 0)
  -- b still sees c1 open when it decides, but c2's ref never
  -- overlaps c1's — the close lands on its own, no LOST_RACE.
  assert(verbs.cmd_done(b, c2, "completed", false, "") == 0,
    "an unbounded done on a different item never contends")
  assert(not item.is_open(check.must(store.load(b, c2))), "c2 is closed")
  assert(publish.sync(a))
  assert(not item.is_open(check.must(store.load(a, c2))), "and reaches a too")
  local all = check.must(store.list(a))
  local back = check.must(store.load(a, parent))
  assert(flow.role(back, all) == "work",
    "the parent is workable again — derived fresh, nothing to have lost")
end

-- `set` never touches `refs/heads/board/seq` (it is not in `gitboard.tl`'s
-- FETCH_FIRST set), so the CLI dispatch builds and pushes it straight
-- against this checkout's own local refs, with no fetch first. Racing
-- it against the SAME item from a checkout that never synced past a's
-- first edit still has to lose cleanly: the push's own
-- `--force-with-lease` is the compare-and-swap, stale or not, and a
-- rejection there is refused as LOST_RACE exactly as a pre-fetched
-- mutation's would be — the skipped fetch only removes a round trip
-- from the common case, never the guarantee.
local function test_an_unbounded_dispatch_against_a_stale_ref_refuses_lost_race()
  local a, b = init_shared("race-unbounded-dispatch")
  local id = file_item(a, "a title worth racing over", "")
  assert(publish.sync(b))

  assert(gitboard.main("set", id, "--title", "a's title wins", "--dir", a.root)
    == 0, "a's set lands")
  -- b's local refs still hold what it synced before a's write above —
  -- exactly the stale-checkout shape, and `set` skips the pre-fetch a
  -- bounded verb like `take`/`block` would still pay for.
  assert(gitboard.main("set", id, "--title", "b's title loses", "--dir", b.root)
    ~= 0, "b's stale set is refused")
  assert(check.must(store.load(b, id)).title == "a's title wins",
    "b's checkout now holds the remote's (a's) state, not its own stale write")
  local remote_all = check.must(store.list(a))
  local b_all = check.must(store.list(b))
  assert(#remote_all == #b_all,
    "b's checkout is equal to the remote after the refusal's re-sync")
end
