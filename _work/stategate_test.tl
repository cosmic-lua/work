#!/usr/bin/env cosmic
local boardtree = require("_work.boardtree")
local check = require("cosmic.check")
local child = require("cosmic.child")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local gitobj = require("_work.gitobj")
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local ksuid = require("_work.ksuid")
local stategate = require("_work.stategate")
local tx = require("_work.statetransaction")

local root = fs.join(fixture.tmpdir, "native-bounded-flow")
assert(fs.remove_all(root) and fs.make_dirs(root))
assert(check.must(child.run({"git", "init", "-q", root})).ok)
local function fresh(parent: string): item.Item
  return check.must(item.decode({id = ksuid.new(), title = "bounded fixture", parent = parent}))
end
local function snapshot(items: {item.Item}): string
  local entries: {gitobj.TreeEntry} = {}
  for _, it in ipairs(items) do
    entries[#entries + 1] = {mode = "40000", otype = "tree", name = it.id,
      sha = check.must(boardtree.build_item(root, it, nil, nil, true))}
  end
  return check.must(gitobj.mktree_write(root, {
        {mode = "100644", otype = "blob", name = "format", sha = check.must(gitobj.hash_object_write(root, "6\n"))},
        {mode = "40000", otype = "tree", name = "items", sha = check.must(gitobj.mktree_write(root, entries))}}))
end
local function mutation(gate: string, changed: {item.Item}): tx.Transition
  local changes: {tx.Change} = {}
  for _, it in ipairs(changed) do
    changes[#changes + 1] = {path = "items/" .. it.id .. "/meta", mode = "100644",
      content = itemtree.encode_meta(it), delete = false}
  end
  return {base = ("a"):rep(40), dependencies = {}, changes = changes, message = "bounded fixture",
    author = {name = "test", email = "test@board", date = "1700000000 +0000"},
    publish_by = 0, bounded = true, gate = gate}
end
local function seed(count: integer): {item.Item}, item.Item, item.Item
  local board = fresh("")
  local outcome = fresh(board.id)
  local first, second = fresh(outcome.id), fresh(outcome.id)
  local all: {item.Item} = {board, outcome, first, second}
  for i = 1, count do
    local it = fresh(outcome.id)
    if i % 3 == 0 then it.pr = i
    elseif i % 3 == 1 then it.handover_head = ("b"):rep(40)
    else it.result = ("c"):rep(40) end
    all[#all + 1] = it
  end
  return all, first, second
end

local function test_bound_counts_handover_and_result()
  local all, target = seed(10)
  local head = snapshot(all)
  target.handover_head = ("d"):rep(40)
  local ok, err = stategate.check(root, head, mutation("doing-bound", {target}))
  assert(not ok and err == "doing bound reached", err)
  local unknown, uerr = stategate.check(root, head, mutation("future-gate", {target}))
  assert(not unknown and uerr == "unknown bounded gate: future-gate", uerr)
end

local function test_bound_projects_the_complete_batch()
  local all, first, second = seed(9)
  local head = snapshot(all)
  first.handover_head = ("d"):rep(40)
  second.result = ("e"):rep(40)
  local ok, err = stategate.check(root, head, mutation("take", {first, second}))
  assert(not ok and err == "doing bound reached", err)
end

local function test_finishing_never_consumes_another_slot()
  local all = seed(11)
  local head = snapshot(all)
  local already = all[#all]
  already.title = "finishing existing work"
  local ok, err = stategate.check(root, head, mutation("take", {already}))
  assert(ok, err)
end

local function test_nonwork_does_not_consume_capacity()
  local all, target = seed(0)
  all[1].handover_head = ("b"):rep(40)
  all[2].pr = 1
  for _ = 1, 12 do
    local container = fresh(all[2].id)
    container.handover_head = ("b"):rep(40)
    all[#all + 1] = container
    all[#all + 1] = fresh(container.id)
  end
  local head = snapshot(all)
  target.handover_head = ("d"):rep(40)
  local ok, err = stategate.check(root, head, mutation("doing-bound", {target}))
  assert(ok, err)
end
local function test_replay_uses_the_shared_dependency_cycle_guard()
  local all, first, second = seed(0)
  second.depends_on = {first.id}
  local head = snapshot(all)
  first.depends_on = {second.id}
  local ok, err = stategate.check(root, head, mutation("depend", {first}))
  assert(not ok and err:find("dependency cycle", 1, true), err)
end

local function test_attach_replay_checks_only_the_changed_parent_edge()
  local all, first, second = seed(0)
  local head = snapshot(all)
  first.parent = second.id
  all[1].order = {all[2].id}
  local ok, err = stategate.check(root, head, mutation("attach", {first, all[1]}))
  assert(ok, err)
  local after = snapshot(all)
  second.parent = first.id
  local cyclic, cerr = stategate.check(root, after, mutation("attach", {second}))
  assert(not cyclic and cerr:find("would make a cycle", 1, true), cerr)
end
local function test_attach_replay_preserves_containering_and_item_checks()
  local all, first = seed(0)
  local retired = fresh(all[1].id); retired.resolution = "completed"
  all[#all + 1] = retired
  local head = snapshot(all)
  first.parent = retired.id
  local ok, err = stategate.check(root, head, mutation("attach", {first}))
  assert(not ok and err:find("parent must be reopened", 1, true), err)
  retired.resolution = ""
  local repaired, rerr = stategate.check(root, head, mutation("attach", {first, retired}))
  assert(repaired, rerr)
  first.title = ""
  local malformed, merr = stategate.check(root, head, mutation("attach", {first, retired}))
  assert(not malformed and merr:find("title", 1, true), merr)
end
