#!/usr/bin/env cosmic
-- How an item gains a parent: `attach` and `new --parent` share one
-- parenting gate (`item.problems`), and this file covers both verbs'
-- surface on it — reparenting through a lost push race, the cycle
-- refusal, and an already-attached pair's no-op success. Split from
-- `_work/gitgraph_test.tl`, which sits against the file cap.

local check = require("cosmic.check")
local graph = require("_work.gitgraph")
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
