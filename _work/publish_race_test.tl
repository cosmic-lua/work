#!/usr/bin/env cosmic
-- The lost-race contract end to end: every final snapshot has one exact
-- canonical parent. Any intervening board write conflicts, and the caller
-- abandons, reopens, and reruns the verb against the new whole board.

local check = require("cosmic.check")
local fixture = require("_work.fixture")
local gitboard = require("_work.gitboard")
local item = require("_work.item")
local snapshot_publish = require("_work.snapshot_publish")
local workspace = require("_work.snapshot_workspace")
local read = require("_work.read")
local store = require("_work.store")
local verbs = require("_work.gitverbs")

local init_shared = fixture.init_shared
local file_item = fixture.file_item

-- Concurrent `done` of a container's last two children is disjoint at the
-- item level, but both decisions still name the same whole-board parent.
-- The stale close conflicts; rerunning it sees the first close and derives
-- the parent as workable from the final combined state.
local function test_concurrent_done_of_last_children_requires_rerun()
  local a, b = init_shared("race-done")
  local root = file_item(a, "an outcome", "")
  local parent = file_item(a, "a slice being decomposed", root)
  local c1 = file_item(a, "the first child", parent)
  local c2 = file_item(a, "the second child", parent)
  fixture.caller_fetch(b)

  assert(verbs.cmd_done(a, c1, "completed", false, "") == 0)
  fixture.caller_publish(a)
  -- b still sees c1 open when it decides, so its whole snapshot is stale.
  assert(verbs.cmd_done(b, c2, "completed", false, "") == 0)
  local stale = check.must(workspace.read(b.root))
  local landed, lerr = snapshot_publish.execute(b.root, stale.commit,
    "origin", nil)
  assert(not landed and lerr:find("conflict", 1, true), lerr)
  assert(gitboard.main("snapshot", "--abandon", stale.commit,
      "--dir", b.root) == 0)
  fixture.caller_fetch(b)
  assert(verbs.cmd_done(b, c2, "completed", false, "") == 0)
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
local function test_a_stale_dispatch_conflicts_without_replay()
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
  local stale = check.must(workspace.read(b.root))
  local pushed, perr = snapshot_publish.execute(b.root, stale.commit,
    "origin", nil)
  assert(not pushed and perr:find("conflict", 1, true), perr)
  assert(gitboard.main("snapshot", "--abandon", stale.commit,
      "--dir", b.root) == 0)
  fixture.caller_fetch(b)
  assert(check.must(store.load(b, id)).title == "a's title wins",
    "b's checkout now holds the remote's (a's) state, not its own stale write")
  local remote_all = check.must(store.list(a))
  local b_all = check.must(store.list(b))
  assert(#remote_all == #b_all,
    "b's checkout is equal to the remote after the refusal's re-sync")
end
