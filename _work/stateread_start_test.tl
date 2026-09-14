#!/usr/bin/env cosmic
--- Count genuinely cold invocation startup in a separate interpreter: neither
--- immutable marker memo nor refsconfig memo may be prewarmed by fixture setup.
local check = require("cosmic.check")
local child = require("cosmic.child")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local proc = require("cosmic.proc")
local store = require("_work.store")
local storewrite = require("_work.storewrite")
local publish = require("_work.publish")

local WORKER < const > = [[
local child = require("cosmic.child")
local store = require("_work.store")
local cachedb = require("_work.cachedb")
local root, mode, id = arg[1], arg[2], arg[3]
if mode == "cold" then cachedb.wipe(root) end
local run, start = child.run, child.start
local total, refs, cats, trees, logs = 0, 0, 0, 0, 0
local function count(argv)
  if argv[1] ~= "git" then return end
  total = total + 1
  for _, word in ipairs(argv) do
    if word == "for-each-ref" then refs = refs + 1 end
    if word == "cat-file" then cats = cats + 1 end
    if word == "ls-tree" then trees = trees + 1 end
    if word == "log" then logs = logs + 1 end
  end
end
child.run = function(argv,options) count(argv); return run(argv,options) end
child.start = function(argv,options) count(argv); return start(argv,options) end
local s, err = store.open(root); assert(s,err)
if mode == "load" then
  local resolved, rerr = store.resolve(s,id); assert(resolved,rerr)
  local it, ierr = store.load(s,resolved); assert(it,ierr)
else
  local all, aerr = store.list(s); assert(all and #all == 2,aerr)
end
local first = total
for _ = 1, 3 do
  if mode == "load" then
    assert(store.resolve(s,id)); assert(store.load(s,id)); store.read_spec(s,id)
  else assert(store.list(s)) end
end
assert(total == first, "repeated reads must reuse the invocation snapshot and decoded native state")
assert(store.close(s))
print(total .. " " .. refs .. " " .. cats .. " " .. trees .. " " .. logs)
]]

local function test_cold_open_shares_the_first_snapshot_and_git_batch()
  local s = fixture.init_state_repo("cold-start-processes")
  local root = s.root
  local id = check.must(ksuid.encode(1700000000, ("c"):rep(16)))
  local board = check.must(store.list(s))[1]
  assert(item.is_parentless(board))
  local it = check.must(item.decode({id = id, title = "Cold read fixture",
        parent = board.id}))
  assert(storewrite.save(s, it, "seed", {change = "Useful prose", non_goals = "No extras"}))
  assert(publish.publish(s))
  assert(store.close(s))
  local worker = fs.join(fixture.tmpdir, "cold-start-worker.lua")
  assert(fs.write(worker, WORKER))
  local interpreter = check.must(proc.interpreter())
  local cold = check.must(child.run({interpreter, worker, root, "cold", id}))
  assert(cold.ok, cold.stdout .. cold.stderr)
  local _total, snapshots, _batches, trees, logs = cold.stdout:match("(%d+) (%d+) (%d+) (%d+) (%d+)")
  assert(snapshots == "1", "cold open/list must share one canonical snapshot: " .. cold.stdout)
  assert(trees == "1" and logs == "1", "native cold read scans one state tree and history: " .. cold.stdout)
  local loaded = check.must(child.run({interpreter, worker, root, "load", id}))
  assert(loaded.ok, loaded.stdout .. loaded.stderr)
  local _loads, load_snapshots, _load_batches, load_trees, load_logs = loaded.stdout:match("(%d+) (%d+) (%d+) (%d+) (%d+)")
  assert(load_snapshots == "1" and load_trees == "1" and load_logs == "1",
    "cold resolve/load reuses the same native state scan: " .. loaded.stdout)
end
