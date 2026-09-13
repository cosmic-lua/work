#!/usr/bin/env cosmic
local check = require("cosmic.check")
local guards = require("_work.graphguards")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local function fresh(parent: string): item.Item
  return check.must(item.decode({id = ksuid.new(), title = "graph sentinel", parent = parent}))
end
local function test_dependency_cycle_has_an_independent_path_witness()
  local a, b, c = fresh(""), fresh(""), fresh("")
  b.depends_on = {c.id}; c.depends_on = {a.id}
  local index = item.by_id({a, b, c})
  local path = guards.cycle_path(index, a.id, b.id)
  assert(path ~= nil and #path == 3 and path[1] == b.id and path[3] == a.id)
  c.depends_on = {}
  assert(guards.cycle_path(index, a.id, b.id) == nil)
end
local function test_parent_cycle_is_not_a_depth_failure()
  local parent = fresh("")
  local descendant = fresh(parent.id)
  local refusal = guards.attach_refusal(item.by_id({parent, descendant}), parent.id, descendant.id)
  assert(refusal ~= nil and refusal:find("would make a cycle", 1, true))
end
local function test_parent_depth_limit_has_an_independent_boundary()
  local board = fresh("")
  local moving = fresh(board.id)
  local all: {item.Item} = {board, moving}
  local parent = board
  for _ = 1, item.MAX_DEPTH - 1 do
    parent = fresh(parent.id); all[#all + 1] = parent
  end
  local index = item.by_id(all)
  assert(guards.attach_refusal(index, moving.id, parent.id) == nil)
  local excessive = fresh(parent.id); index[excessive.id] = excessive
  local refusal = guards.attach_refusal(index, moving.id, excessive.id)
  assert(refusal ~= nil and refusal:find("parent chain is broken", 1, true))
end
