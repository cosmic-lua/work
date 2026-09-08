#!/usr/bin/env cosmic
-- The lost-race contract end to end, through real verbs: a mutation
-- whose guards were decided against pre-race state is never replayed
-- onto the merged board. The shape that used to slip through a clean
-- rebase — the last two children of one container closing at once
-- with nobody re-phasing the parent — is refused with LOST_RACE, and
-- the RE-RUN, deciding afresh against the merged state, does the
-- right thing the stale run could not see.

local check = require("cosmic.check")
local fixture = require("_work.fixture")
local gitboard = require("_work.gitboard")
local item = require("_work.item")
local prepared = require("_work.prepared")
local publish = require("_work.publish")
local read = require("_work.read")
local store = require("_work.store")
local verbs = require("_work.gitverbs")

local init_shared = fixture.init_shared
local file_item = fixture.file_item

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
  fixture.caller_fetch(b)

  assert(verbs.cmd_done(a, c1, "completed", false, "") == 0)
  fixture.caller_publish(a)
  -- b still sees c1 open when it decides, but c2's ref never
  -- overlaps c1's — the close lands on its own, no LOST_RACE.
  assert(verbs.cmd_done(b, c2, "completed", false, "") == 0,
    "an unbounded done on a different item never contends")
  fixture.caller_publish(b)
  assert(not item.is_open(check.must(store.load(b, c2))), "c2 is closed")
  fixture.caller_fetch(a)
  assert(not item.is_open(check.must(store.load(a, c2))), "and reaches a too")
  check.must(store.list(a))
  local c = check.must(store.read(a))
  local back = check.must(store.load(a, parent))
  assert(check.must(read.role(c, back.id)) == "work",
    "the parent is workable again — derived fresh, nothing to have lost")
end

-- A stale offline dispatch may prepare successfully: no remote is
-- consulted during mutation. Its caller-owned leased push is the CAS;
-- after a fetch, refresh classifies the staged successor as a lost
-- race and canonical reads expose the winner.
local function test_a_stale_dispatch_is_classified_after_caller_transport()
  local a, b = init_shared("race-unbounded-dispatch")
  local id = file_item(a, "a title worth racing over", "")
  fixture.caller_fetch(b)

  assert(gitboard.main("set", id, "--title", "a's title wins", "--dir", a.root)
    == 0, "a's set prepares")
  fixture.caller_publish(a)
  -- b's local refs still hold what it synced before a's write above —
  -- exactly the stale-checkout shape, and `set` skips the pre-fetch a
  -- bounded verb like `take`/`block` would still pay for.
  assert(gitboard.main("set", id, "--title", "b's title loses", "--dir", b.root)
    == 0, "b's stale set can be prepared offline")
  local transactions = check.must(prepared.list(b.root))
  assert(#transactions == 1, "b has one prepared successor")
  local pushed = prepared.execute(b.root, prepared.push_argv(transactions[1]))
  assert(not pushed, "the caller's leased push is refused")
  local fetched, ferr = prepared.execute(b.root, prepared.fetch_argv())
  assert(fetched, "caller fetches the winning refs: " .. ferr)
  local synced, serr = publish.sync(b)
  assert(not synced and serr:find("lost their ref lease", 1, true) ~= nil,
    "refresh identifies the stale prepared transaction: " .. serr)
  assert(check.must(store.load(b, id)).title == "a's title wins",
    "b's checkout now holds the remote's (a's) state, not its own stale write")
  local remote_all = check.must(store.list(a))
  local b_all = check.must(store.list(b))
  assert(#remote_all == #b_all,
    "b's checkout is equal to the remote after the refusal's re-sync")
end
