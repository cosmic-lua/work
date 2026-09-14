#!/usr/bin/env cosmic
--- Whole-board race behavior through ordinary verbs. Every proposal names one
--- exact canonical parent; a writer never rebases or replays stale intent.
local check = require("cosmic.check")
local fixture = require("_work.fixture")
local gitboard = require("_work.gitboard")
local gitdepend = require("_work.gitdepend")
local graph = require("_work.gitgraph")
local item = require("_work.item")
local snapshot_publish = require("_work.snapshot_publish")
local workspace = require("_work.snapshot_workspace")
local store = require("_work.store")
local write = require("_work.storewrite")

local function shared(name: string): store.Store, store.Store, string, string
  local a, b = fixture.init_shared(name)
  local outcome = fixture.file_item(a, "race outcome", "")
  local left = fixture.file_item(a, "left leaf", outcome)
  local right = fixture.file_item(a, "right leaf", outcome)
  fixture.caller_fetch(b)
  return a, b, left, right
end

local function conflict_and_abandon(s: store.Store)
  local stale = check.must(workspace.read(s.root))
  local ok, err = snapshot_publish.execute(s.root, stale.commit, "origin", nil)
  assert(not ok and err:find("conflict", 1, true), err)
  assert(gitboard.main("snapshot", "--abandon", stale.commit,
      "--dir", s.root) == 0)
  fixture.caller_fetch(s)
end

-- Disjoint item edits still have the same canonical parent. The loser reopens
-- and applies its intent explicitly, after which both edits are present.
local function test_disjoint_writers_conflict_then_rerun()
  local a, b, left, right = shared("snapshot-disjoint")
  local la = check.must(store.load(a, left))
  local rb = check.must(store.load(b, right))
  la.title, rb.title = "left by a", "right by b"
  write.set_session(a, "writer-a"); write.set_op(a, "set")
  write.set_session(b, "writer-b"); write.set_op(b, "set")
  assert(write.save(a, la, "set left by a"))
  assert(write.save(b, rb, "set right by b"))
  fixture.caller_publish(a)
  conflict_and_abandon(b)
  rb = check.must(store.load(b, right)); rb.title = "right by b"
  assert(write.save(b, rb, "set right by b"))
  fixture.caller_publish(b)
  fixture.caller_fetch(a)
  assert(check.must(store.load(a, left)).title == "left by a")
  assert(check.must(store.load(a, right)).title == "right by b")
end

-- A dependency valid at the old head is not replayed over a racing edge.
-- After reopening, the ordinary verb sees and refuses the cycle.
local function test_dependency_cycle_race_requires_a_fresh_decision()
  local a, b, left, right = shared("snapshot-cycle")
  assert(gitdepend.cmd_depend(b, left, right) == 0)
  assert(gitdepend.cmd_depend(a, right, left) == 0)
  fixture.caller_publish(a)
  conflict_and_abandon(b)
  assert(gitdepend.cmd_depend(b, left, right) ~= 0,
    "the rerun sees the winner's edge and refuses the cycle")
  assert(workspace.read(b.root) == nil, "a refused rerun composes nothing")
end

-- A blocker finishing after a stale depend decision advances the whole head.
-- The rerun sees the completed blocker and refuses the obsolete edge.
local function test_finished_blocker_race_requires_a_fresh_decision()
  local a, b, waiter, blocker = shared("snapshot-blocker")
  assert(gitdepend.cmd_depend(b, waiter, blocker) == 0)
  local done = check.must(store.load(a, blocker))
  done.resolution = "completed"
  write.set_session(a, "finisher"); write.set_op(a, "done")
  assert(write.save(a, done, "finish blocker"))
  fixture.caller_publish(a)
  conflict_and_abandon(b)
  assert(gitdepend.cmd_depend(b, waiter, blocker) ~= 0,
    "the rerun sees that the blocker is done")
end

-- Once the dependency lands, finishing its blocker remains valid and leaves
-- the declared edge as history.
local function test_blocker_done_after_depend_lands_succeeds()
  local s = fixture.init_state_repo("snapshot-depend-then-done")
  local outcome = fixture.file_item(s, "depend outcome", "")
  local waiter = fixture.file_item(s, "waiter", outcome)
  local blocker = fixture.file_item(s, "blocker", outcome)
  assert(gitdepend.cmd_depend(s, waiter, blocker) == 0)
  fixture.caller_publish(s)
  local done = check.must(store.load(s, blocker)); done.resolution = "completed"
  write.set_session(s, "finisher"); write.set_op(s, "done")
  assert(write.save(s, done, "finish blocker"))
  fixture.caller_publish(s)
  local got = check.must(store.load(s, waiter))
  assert(#got.depends_on == 1 and got.depends_on[1] == blocker)
  assert(not item.is_open(check.must(store.load(s, blocker))))
end

-- A bare attach changes the parent's derived role while writing the child.
-- Whole-item authority protects both new and old parent membership facts.
local function test_bare_attach_refuses_a_foreign_claimed_parent()
  local s = fixture.init_state_repo("gate-attach-parent-claim")
  local _root, parent = fixture.root_with_leaf(s)
  local mover = fixture.file_item(s, "an unpositioned outcome", "")
  fixture.claim_item(s, parent, "holder")
  assert(graph.cmd_attach(s, mover, parent, nil, nil, "stranger") ~= 0)
  assert(check.must(store.load(s, mover)).parent ~= parent)
end

local function test_bare_attach_refuses_a_foreign_claimed_old_parent()
  local s = fixture.init_state_repo("gate-attach-old-parent-claim")
  local _root, old_parent = fixture.root_with_leaf(s)
  local destination = fixture.file_item(s, "destination outcome", "")
  local mover = fixture.file_item(s, "unpositioned mover", "")
  assert(graph.cmd_attach(s, mover, old_parent) == 0)
  fixture.caller_publish(s)
  fixture.claim_item(s, old_parent, "old-parent-holder")
  assert(graph.cmd_attach(s, mover, destination, nil, nil, "stranger") ~= 0)
  assert(check.must(store.load(s, mover)).parent == old_parent)
end
