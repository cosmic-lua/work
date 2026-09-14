#!/usr/bin/env cosmic
local check = require("cosmic.check")
local child = require("cosmic.child")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local stateinit = require("_work.stateinit")
local store = require("_work.store")
local write = require("_work.storewrite")
local statewrite = require("_work.statewrite")
local publish = require("_work.publish")
local staging = require("_work.statestaging")
local boardread = require("_work.boardread")
local boardhistory = require("_work.boardhistory")
local refs = require("_work.refs")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local function setup(name: string): string
  local root = fs.join(fixture.tmpdir, name)
  assert(fs.remove_all(root) and fs.make_dirs(root))
  assert(stateinit.init(root))
  assert(check.must(child.run({"git", "config", "gitboard.mode", "local"}, {cwd = root})).ok)
  return root
end
local function new_item(title: string, parent: string): item.Item
  return check.must(item.decode({id = ksuid.new(), title = title,
        parent = parent}))
end
local function test_native_save_log_and_no_legacy_refs()
  local root = setup("native-write-save")
  local s = check.must(store.open(root))
  local base = s.state_head
  local board = check.must(store.list(s))[1]
  assert(item.is_parentless(board))
  local a, b = new_item("first", board.id), new_item("second", board.id)
  write.set_session(s, "test")
  write.set_op(s, "new")
  assert(item.record_involvement(a.speccers, "test"))
  assert(write.save(s, a, "new both by test", {change = "Spec", non_goals = ""}, {b}))
  assert(check.must(refs.read_ref(root, "refs/heads/state")) == base)
  assert(publish.publish(s))
  local history = check.must(boardhistory.read(root, s.state_head))
  assert(history.tip_by_id[a.id] == history.tip_by_id[b.id])
  assert(store.read_spec(s, a.id).change == "Spec")
  local loaded = check.must(store.load(s, a.id))
  local before = s.state_head
  local ok, err = write.save(s, loaded, "same")
  assert(ok and store.is_noop(err) and s.state_head == before)
  assert(statewrite.log(s, loaded, "note " .. a.id, "Persistent note"))
  assert(publish.publish(s))
  local snapshot = check.must(boardread.list(root, s.state_head))
  assert(snapshot.logs_by_id[a.id] ~= nil)
  assert(#check.must(refs.for_each_ref_raw(root, {"refs/heads/items", "refs/heads/ended", "refs/heads/claim-batches", "refs/heads/board/seq"})) == 0)
  assert(#check.must(staging.list(root)) == 0)
  assert(store.close(s))
end
