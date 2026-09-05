#!/usr/bin/env cosmic
-- How an item gains a parent: `attach` and `new --parent` share one
-- parenting gate (`item.problems`), and this file covers both verbs'
-- surface on it — reparenting through a lost push race, the cycle
-- refusal, and an already-attached pair's no-op success. Split from
-- `_work/gitgraph_test.tl`, which sits against the file cap.

local check = require("cosmic.check")
local graph = require("_work.gitgraph")
local rank = require("_work.gitrank")
local store = require("_work.store")
local fixture = require("_work.fixture")
local publish = require("_work.publish")

local init_shared = fixture.init_shared
local init_state_repo = fixture.init_state_repo
local root_with_leaf = fixture.root_with_leaf
local file_item = fixture.file_item
local commits = fixture.commits

-- Re-parenting after a lost push race: `attach` has no WIP gate up
-- front — triage is a decision already made — so after the race the
-- RE-RUN lands exactly as the first run would have. `attach` writes
-- only the id's OWN ref (`other`, the new parent, is untouched here —
-- it carries no claim/reviewer/hold for `containered` to clear), so
-- the race has to move `leaf`'s ref itself: b re-parents it first,
-- out from under a's stale read.
local function test_a_reparent_survives_a_rebase()
  local a, b = init_shared("attach-race")
  local goal, leaf = root_with_leaf(a)
  local other = file_item(a, "another leaf", goal)
  local another = file_item(a, "yet another leaf", goal)
  assert(publish.sync(b))
  assert(graph.cmd_attach(b, leaf, another) == 0,
    "b moves leaf's ref first")
  assert(graph.cmd_attach(a, leaf, other) ~= 0,
    "the stale run is refused, not replayed")
  assert(graph.cmd_attach(a, leaf, other) == 0,
    "the re-run lands against the merged board")
  local after = check.must(store.load(a, leaf))
  assert(after.parent == other, "the re-parent landed: " .. after.parent)
end

-- Attaching under one's own descendant would make a cycle.
local function test_attach_refuses_a_cycle()
  local s = init_state_repo("cycle")
  local _, leaf = root_with_leaf(s)
  local kid = file_item(s, "a child", leaf)
  assert(graph.cmd_attach(s, leaf, kid) ~= 0, "a cycle must be refused")
  assert(check.must(store.load(s, leaf)).parent ~= kid, "and not written")
end

-- Attaching a pair already attached asks for the state the board already
-- has — a no-op that succeeds, printing store's own line, not a misleading
-- "now under" as though a fresh edge had landed.
local function test_attach_of_an_already_attached_pair_is_a_noop_success()
  local s = init_state_repo("attach-noop")
  local goal, leaf = root_with_leaf(s)
  local before, seen, old_print = commits(s), "", _G.print
  _G.print = function(msg: any) seen = tostring(msg) end
  local code = graph.cmd_attach(s, leaf, goal)
  _G.print = old_print
  assert(code == 0 and commits(s) == before and seen:find("nothing to record", 1, true) ~= nil, seen)
end

-- `attach ID PARENT --before X` places the child among PARENT's other
-- children in the SAME publish that parents it: the child's own ref
-- (its `parent`) and PARENT's ref (its `order`) each land their own
-- commit, one atomic push.
local function test_attach_before_places_and_parents_in_one_publish()
  local s = init_state_repo("attach-before")
  local goal, _leaf = root_with_leaf(s)
  local other = file_item(s, "another leaf", goal)
  assert(rank.cmd_rank(s, other, "", "", true) == 0,
    "rank --last should give other a position")
  local mover = file_item(s, "a mover", "")
  local before = commits(s)
  assert(graph.cmd_attach(s, mover, goal, other, "") == 0,
    "attach --before should be accepted")
  assert(commits(s) == before + 2,
    "one push, two commits: the mover and the parent it entered")
  local moved = check.must(store.load(s, mover))
  assert(moved.parent == goal, "the mover is now goal's child")
  local reparent = check.must(store.load(s, goal))
  assert(#reparent.order == 2 and reparent.order[1] == mover
    and reparent.order[2] == other,
    "mover lands immediately before other: " .. table.concat(reparent.order, ","))
end

-- The mirror case: `--after` places immediately after X.
local function test_attach_after_places_the_child_past_x()
  local s = init_state_repo("attach-after")
  local goal, _leaf = root_with_leaf(s)
  local other = file_item(s, "another leaf", goal)
  assert(rank.cmd_rank(s, other, "", "", true) == 0)
  local mover = file_item(s, "a mover", "")
  assert(graph.cmd_attach(s, mover, goal, "", other) == 0,
    "attach --after should be accepted")
  local reparent = check.must(store.load(s, goal))
  assert(#reparent.order == 2 and reparent.order[1] == other
    and reparent.order[2] == mover,
    "mover lands immediately after other: " .. table.concat(reparent.order, ","))
end

-- X has to already be a POSITIONED child of PARENT — an unranked
-- sibling is refused the same way `rank` itself refuses one, rather
-- than silently landing the mover at the front.
local function test_attach_refuses_placing_against_an_unpositioned_sibling()
  local s = init_state_repo("attach-unpositioned")
  local goal, leaf = root_with_leaf(s)
  local mover = file_item(s, "a mover", "")
  assert(graph.cmd_attach(s, mover, goal, leaf, "") ~= 0,
    "leaf carries no position among goal's children yet")
  assert(check.must(store.load(s, mover)).parent == "",
    "the refused attach never wrote anything")
end

-- --before and --after together name two positions for one item.
local function test_attach_refuses_before_and_after_together()
  local s = init_state_repo("attach-both")
  local goal, _leaf = root_with_leaf(s)
  local other = file_item(s, "another leaf", goal)
  assert(rank.cmd_rank(s, other, "", "", true) == 0)
  local mover = file_item(s, "a mover", "")
  assert(graph.cmd_attach(s, mover, goal, other, other) ~= 0,
    "at most one of --before/--after may be given")
end
