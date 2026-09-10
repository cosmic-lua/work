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
local prepared = require("_work.prepared")
local refs = require("_work.refs")

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
  fixture.caller_fetch(b)
  assert(graph.cmd_attach(b, leaf, another) == 0,
    "b moves leaf's ref first")
  fixture.caller_publish(b)

  assert(graph.cmd_attach(a, leaf, other) == 0,
    "the stale caller may prepare against its fetched snapshot")
  local pending = check.must(prepared.list(a.root))
  assert(#pending == 1, "the stale move has one durable transaction")
  local pushed = prepared.execute(a.root, prepared.push_argv(pending[1]))
  assert(not pushed, "the remote lease, not local preparation, rejects the race")
  assert(prepared.execute(a.root, prepared.fetch_argv()),
    "the caller refreshes its tracking refs after the rejected push")
  check.must(store.close(a))
  local outcomes = check.must(prepared.refresh(a.root))
  assert(#outcomes == 1 and outcomes[1].state == "lost-race",
    "refresh classifies the rejected lease")
  assert(check.must(refs.read_ref(a.root, pending[1].staging_ref)) == refs.ZERO_SHA)
  assert(outcomes[1].quarantine_ref == "refs/gitboard/quarantined/lost-race/"
    .. pending[1].id)
  assert(check.must(refs.read_ref(a.root, outcomes[1].quarantine_ref))
    == pending[1].manifest, "the diagnosed transaction remains inspectable")

  assert(graph.cmd_attach(a, leaf, other) == 0,
    "the re-run lands against the merged board")
  fixture.caller_publish(a)
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
-- "now under" as though a fresh edge had landed. Re-attaching under the
-- SAME parent moves nothing, so the entry the child already holds there
-- is not a stale leftover to prune: the guard that tells the two cases
-- apart is the old parent's id differing from the new one.
local function test_attach_of_an_already_attached_pair_is_a_noop_success()
  local s = init_state_repo("attach-noop")
  local goal, leaf = root_with_leaf(s)
  local before_order = table.concat(check.must(store.load(s, goal)).order, ",")
  local before, seen, old_print = commits(s), "", _G.print
  _G.print = function(msg: any) seen = tostring(msg) end
  local code = graph.cmd_attach(s, leaf, goal)
  _G.print = old_print
  assert(code == 0 and commits(s) == before and seen:find("nothing to record", 1, true) ~= nil, seen)
  local after_order = table.concat(check.must(store.load(s, goal)).order, ",")
  assert(after_order == before_order,
    "a same-parent attach leaves order untouched: " .. after_order)
end

-- The old parent's stale `order` entry is pruned in the SAME publish
-- that moves the child: `attach` writes both refs, one push, so a
-- lost race refuses the whole move rather than leaving the entry
-- behind for `fsck` to report.
local function test_attach_prunes_a_positioned_child_from_its_old_parents_order()
  local s = init_state_repo("attach-prune")
  local goal, leaf = root_with_leaf(s)
  local other = file_item(s, "another outcome", "")
  local before = commits(s)
  assert(graph.cmd_attach(s, leaf, other) == 0, "attach should be accepted")
  assert(commits(s) == before + 2,
    "one push, two commits: the leaf and the old parent it left")
  local moved = check.must(store.load(s, leaf))
  assert(moved.parent == other, "leaf is now other's child")
  local old_parent = check.must(store.load(s, goal))
  local still_there = false
  for _, v in ipairs(old_parent.order) do
    if v == leaf then still_there = true end
  end
  assert(not still_there,
    "no stale entry left behind: " .. table.concat(old_parent.order, ","))
end

-- An UNPOSITIONED child's old parent never named it, so pruning finds
-- nothing to remove: the move writes only the child's own ref.
local function test_attach_of_an_unpositioned_child_writes_only_the_child()
  local s = init_state_repo("attach-prune-unpositioned")
  local stray = file_item(s, "a stray outcome", "")
  local other = file_item(s, "another outcome", "")
  local before = commits(s)
  assert(graph.cmd_attach(s, stray, other) == 0, "attach should be accepted")
  assert(commits(s) == before + 1,
    "one commit: the child alone, nothing to prune on an unpositioned move")
  local moved = check.must(store.load(s, stray))
  assert(moved.parent == other, "stray is now other's child")
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
  local mover_at: integer = nil
  local other_at: integer = nil
  for i, v in ipairs(reparent.order) do
    if v == mover then mover_at = i end
    if v == other then other_at = i end
  end
  assert(mover_at ~= nil and other_at ~= nil and mover_at == other_at - 1,
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
  local mover_at: integer = nil
  local other_at: integer = nil
  for i, v in ipairs(reparent.order) do
    if v == mover then mover_at = i end
    if v == other then other_at = i end
  end
  assert(mover_at ~= nil and other_at ~= nil and mover_at == other_at + 1,
    "mover lands immediately after other: " .. table.concat(reparent.order, ","))
end

-- X has to already be a POSITIONED child of PARENT — an unranked
-- sibling is refused the same way `rank` itself refuses one, rather
-- than silently landing the mover at the front. `new` can no longer
-- produce an unranked child under an ordinary parent, so the
-- unpositioned sibling here is built through a bare `attach`, which
-- still leaves an item unranked when no --before/--after names it.
local function test_attach_refuses_placing_against_an_unpositioned_sibling()
  local s = init_state_repo("attach-unpositioned")
  local goal, _leaf = root_with_leaf(s)
  local stray = file_item(s, "a stray outcome", "")
  assert(graph.cmd_attach(s, stray, goal) == 0,
    "attach with no position should be accepted")
  local mover = file_item(s, "a mover", "")
  local before_parent = check.must(store.load(s, mover)).parent
  assert(graph.cmd_attach(s, mover, goal, stray, "") ~= 0,
    "stray carries no position among goal's children yet")
  assert(check.must(store.load(s, mover)).parent == before_parent,
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
