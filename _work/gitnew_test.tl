#!/usr/bin/env cosmic
-- `new`'s own placement option: `--before`/`--after` land a freshly
-- minted child positioned among its new siblings in the same publish
-- that files it, and refuse the same way `attach`'s do. Split out
-- rather than added to `gitgraph_test.tl`, which sits close to the
-- file cap.

local check = require("cosmic.check")
local graph = require("_work.gitgraph")
local rank = require("_work.gitrank")
local store = require("_work.store")
local fixture = require("_work.fixture")

local init_state_repo = fixture.init_state_repo
local root_with_leaf = fixture.root_with_leaf
local commits = fixture.commits

-- `new TITLE --parent P --after X` files the child under P AND places
-- it immediately after X's position, one push, two commits: the new
-- item's own ref and P's (for its `order`).
local function test_new_after_files_and_places_in_one_publish()
  local s = init_state_repo("new-after")
  local goal, leaf = root_with_leaf(s)
  assert(rank.cmd_rank(s, leaf, "", "", true) == 0,
    "rank --last should give leaf a position")
  local before_count = 0
  for _, _i in ipairs(check.must(store.list(s))) do
    before_count = before_count + 1
  end
  local before_commits = commits(s)
  assert(graph.cmd_new(s, "a later slice", goal, nil, "", nil, "", "", leaf) == 0,
    "new --parent --after should be accepted")
  local after = check.must(store.list(s))
  assert(#after == before_count + 1, "exactly one item was filed")
  assert(commits(s) == before_commits + 2,
    "one push, two commits: the new item and the parent it entered")
  local found: string = nil
  for _, i in ipairs(after) do
    if i.parent == goal and i.id ~= leaf then
      found = i.id
    end
  end
  assert(found ~= nil, "the new child is under goal")
  local reparent = check.must(store.load(s, goal))
  assert(#reparent.order == 2 and reparent.order[1] == leaf
    and reparent.order[2] == found,
    "the new child lands immediately after leaf: "
    .. table.concat(reparent.order, ","))
end

-- `--before`/`--after` name a sibling under the NEW parent, so they
-- are refused with no `--parent` at all — a root has no such list;
-- `rank` places roots.
local function test_new_refuses_before_after_with_no_parent()
  local s = init_state_repo("new-rootless")
  local _goal, leaf = root_with_leaf(s)
  assert(rank.cmd_rank(s, leaf, "", "", true) == 0)
  assert(graph.cmd_new(s, "a stray", "", nil, "", nil, "", leaf, "") ~= 0,
    "--before with no --parent is refused")
end

-- X has to already be a positioned child of the NEW parent.
local function test_new_refuses_placing_against_an_unpositioned_sibling()
  local s = init_state_repo("new-unpositioned")
  local goal, leaf = root_with_leaf(s)
  assert(graph.cmd_new(s, "a later slice", goal, nil, "", nil, "", "", leaf) ~= 0,
    "leaf carries no position among goal's children yet")
end
