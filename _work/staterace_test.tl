#!/usr/bin/env cosmic
--- The write fence on one branch: what a mutation records as READ, which
--- races that makes it lose, and which racing fact its bounded gate is the
--- one to catch. A listing verb sees the whole board, but seeing it is not
--- depending on it: fencing every path a read TOUCHED would make every pair
--- of writers conflict, which is the property one branch is supposed to buy.
local check = require("cosmic.check")
local child = require("cosmic.child")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local graph = require("_work.gitgraph")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local publish = require("_work.publish")
local staging = require("_work.statestaging")
local native = require("_work.statepublish")
local stateclaim = require("_work.stateclaim")
local stateinit = require("_work.stateinit")
local statewrite = require("_work.statewrite")
local store = require("_work.store")
local write = require("_work.storewrite")

local function setup(name: string): string
  local root = fs.join(fixture.tmpdir, name)
  assert(fs.remove_all(root) and fs.make_dirs(root))
  assert(stateinit.init(root))
  assert(check.must(child.run({"git", "config", "gitboard.mode", "local"}, {cwd = root})).ok)
  return root
end

local function new_item(title: string, parent?: string): item.Item
  return check.must(item.decode({id = ksuid.new(), title = title, parent = parent}))
end

--- A board with an outcome and two leaves under it, published.
local function seeded(name: string): string, item.Item, item.Item
  local root = setup(name)
  local s = check.must(store.open(root))
  local board: item.Item = nil
  for _, candidate in ipairs(check.must(store.list(s))) do
    if (candidate.parent or "") == "" then board = candidate break end
  end
  assert(board ~= nil, "state init created the board item")
  local outcome = new_item("an outcome", board.id)
  board.order = {outcome.id}
  local left, right = new_item("left leaf", outcome.id), new_item("right leaf", outcome.id)
  outcome.order = {left.id, right.id}
  write.set_session(s, "seed")
  write.set_op(s, "new")
  assert(write.save(s, left, "new three by seed",
      {change = "Do exactly this.\n", non_goals = "Not that.\n"},
      {right, outcome, board}))
  assert(publish.publish(s))
  assert(store.close(s))
  return root, left, right
end

--- Every path the prepared transaction fences, as its frozen chain records
--- them — the dependency set `statepublish` compares between B and H.
local function fenced(root: string, receipt_ref: string): {string: string}
  local receipt = check.must(staging.load(root, receipt_ref))
  local out: {string: string} = {}
  for _, transition in ipairs(receipt.transitions) do
    for _, dependency in ipairs(transition.dependencies) do out[dependency.path] = dependency.id end
  end
  return out
end

local function count(paths: {string: string}): integer
  local n = 0
  for _ in pairs(paths) do n = n + 1 end
  return n
end

-- An ordinary item mutation fences `items/<id>` and `claims/<id>`, and that
-- is all — even when the verb that made it read the whole board first, as
-- every verb built on `store.list` does.
local function test_a_listing_mutation_fences_only_the_item_it_writes()
  local root, left = seeded("fence-scope")
  local s = check.must(store.open(root))
  local all = check.must(store.list(s))
  assert(#all >= 3, "the seeded board carries the board item and three more")
  local target = check.must(store.load(s, left.id))
  target.title = "left renamed"
  write.set_session(s, "writer")
  write.set_op(s, "set")
  assert(write.save(s, target, "set " .. left.id:sub(1, 8)))
  local paths = fenced(root, s.state_receipt)
  assert(paths["items/" .. left.id] ~= nil and paths["claims/" .. left.id] ~= nil,
    "the written item's own two paths are the fence")
  assert(count(paths) == 2, "a whole-board read is not a whole-board fence: " .. count(paths))
  assert(publish.publish(s))
  assert(store.close(s))
end

-- Two writers from one base, each having listed the whole board, touching
-- different items: both land, the second by rebase.
local function test_disjoint_listing_writers_both_land()
  local root, left, right = seeded("fence-disjoint")
  local a, b = check.must(store.open(root)), check.must(store.open(root))
  assert(check.must(store.list(a)) ~= nil and check.must(store.list(b)) ~= nil)
  local la, rb = check.must(store.load(a, left.id)), check.must(store.load(b, right.id))
  la.title = "by a"; rb.title = "by b"
  write.set_op(a, "set"); write.set_op(b, "set")
  assert(write.save(a, la, "set left by a"))
  assert(write.save(b, rb, "set right by b"))
  assert(publish.publish(a))
  local ok, err = publish.publish(b)
  assert(ok, "a disjoint second writer rebases rather than losing: " .. err)
  local current = check.must(store.open(root))
  assert(check.must(store.load(current, left.id)).title == "by a")
  assert(check.must(store.load(current, right.id)).title == "by b")
  assert(store.close(current))
end

-- The edit racing a claim: the loser staged its edit before someone else's
-- claim of the same item landed, and `claims/<id>` is one of the two paths
-- it recorded, so the claim is what makes it lose.
local function test_an_edit_staged_before_a_claim_loses_to_it()
  local root, left = seeded("fence-claim")
  local loser = check.must(store.open(root))
  local stale = check.must(store.load(loser, left.id))
  stale.title = "edited without the claim"
  write.set_op(loser, "set")
  assert(write.save(loser, stale, "set " .. left.id:sub(1, 8)))
  assert(fenced(root, loser.state_receipt)["claims/" .. left.id] ~= nil,
    "an item mutation records the claim blob it read")
  local holder = check.must(store.open(root))
  local acquired = stateclaim.prepare(root, holder.state_head,
    {{id = left.id, product_base = ("b"):rep(40)}}, "take", "other-session", os.time(), false, "")
  assert(next(acquired.refused) == nil and #acquired.changes == 1)
  for _, dependency in ipairs(acquired.dependencies) do holder.state_reads[dependency.path] = dependency.id end
  holder.session, holder.op, holder.bounded = "other-session", "claim", true
  assert(statewrite.transition(holder, acquired.changes, "claim take by other-session",
      acquired.publish_by, "take"))
  assert(publish.publish(holder))
  local ok, err = publish.publish(loser)
  assert(not ok and err == store.LOST_RACE, "the edit loses to the claim: " .. err)
  assert(#check.must(staging.list(root)) == 0, "a lost race leaves no republishable receipt")
end

-- A bounded mutation's own gate is what catches a racing fact its two fenced
-- paths cannot see: `depend` staged at B, an edit landing at H that makes the
-- proposed blocker wait on the waiter, and the cycle walk re-run against H.
local function test_depend_racing_an_edit_on_its_cycle_path_is_refused()
  local root, left, right = seeded("fence-depend")
  local waiter = check.must(store.open(root))
  local it = check.must(store.load(waiter, left.id))
  it.depends_on = {right.id}
  write.set_session(waiter, "waiter")
  write.set_op(waiter, "depend")
  write.set_bounded(waiter, true)
  assert(write.save(waiter, it, "depend " .. left.id:sub(1, 8) .. " on " .. right.id:sub(1, 8)))
  local fence = fenced(root, waiter.state_receipt)
  assert(count(fence) == 2 and fence["items/" .. right.id] == nil,
    "the cycle walk is revalidated, not fenced onto every item it read")
  local racer = check.must(store.open(root))
  local blocker = check.must(store.load(racer, right.id))
  blocker.depends_on = {left.id}
  write.set_op(racer, "depend")
  write.set_bounded(racer, true)
  assert(write.save(racer, blocker, "depend " .. right.id:sub(1, 8) .. " on " .. left.id:sub(1, 8)))
  assert(publish.publish(racer))
  local ok, err = publish.publish(waiter)
  assert(not ok and err:find("dependency cycle", 1, true) ~= nil,
    "the re-run depend gate refuses the cycle the race created: " .. err)
end

-- A bare attach changes the parent's derived role while writing only the
-- child's bytes. Whole-item authority still applies to that membership edit.
local function test_bare_attach_refuses_a_foreign_claimed_parent()
  local s = fixture.init_state_repo("gate-attach-parent-claim")
  local _root, parent = fixture.root_with_leaf(s)
  local mover = fixture.file_item(s, "an unpositioned outcome", "")
  fixture.claim_item(s, parent, "holder")
  assert(graph.cmd_attach(s, mover, parent, nil, nil, "stranger") ~= 0)
  assert(check.must(store.load(s, mover)).parent ~= parent)
  assert(check.must(store.load(s, parent)).claim == "holder")
end

local function prepare_native_take(s: store.Store, id: string, session: string)
  check.must(store.load(s, id))
  local result = stateclaim.prepare(s.root, s.state_head,
    {{id = id, product_base = s.state_head}}, "take", session,
    os.time(), false, "")
  assert(next(result.refused) == nil, result.refused[id] or result.refused.batch)
  for _, dependency in ipairs(result.dependencies) do
    s.state_paths[dependency.path], s.state_reads[dependency.path] =
    dependency.id, dependency.id
  end
  s.session, s.op, s.bounded = session, "take", true
  assert(statewrite.transition(s, result.changes, "take by " .. session,
      result.publish_by, "take"))
end

local function take_membership_race(name: string): store.Store, store.Store,
  string, string
  local a, b = fixture.init_shared(name)
  local _root, target = fixture.root_with_leaf(a)
  local target_item = check.must(store.load(a, target))
  write.set_op(a, "spec")
  assert(write.save(a, target_item, "ready target",
      {change = "Do exactly this.\n", non_goals = "Not that.\n"}))
  assert(publish.publish(a))
  fixture.caller_publish(a)
  local newcomer = fixture.file_item(a, "an unpositioned outcome", "")
  fixture.caller_fetch(b)
  return a, b, target, newcomer
end

local function test_take_prepared_before_child_attach_rechecks_workability()
  local taker, attacher, target, newcomer =
  take_membership_race("take-before-attach")
  prepare_native_take(taker, target, "worker")
  local pending = check.must(staging.list(taker.root))
  assert(#pending == 1)
  assert(graph.cmd_attach(attacher, newcomer, target, nil, nil, "attacher") == 0)
  fixture.caller_publish(attacher)
  local ok, err = native.execute(taker.root, pending[1])
  assert(not ok and err:find("not workable", 1, true), err)
end

local function test_child_attach_prepared_before_take_loses_parent_claim_fence()
  local taker, attacher, target, newcomer =
  take_membership_race("attach-before-take")
  assert(graph.cmd_attach(attacher, newcomer, target, nil, nil, "attacher") == 0)
  local pending = check.must(staging.list(attacher.root))
  assert(#pending == 1)
  prepare_native_take(taker, target, "worker")
  fixture.caller_publish(taker)
  local ok, err = native.execute(attacher.root, pending[1])
  assert(not ok and err == store.LOST_RACE,
    "attach fences the new parent's claim path: " .. err)
end

-- A blocker that finishes after depend was staged invalidates the newly added
-- edge. The blocker lives at a disjoint path, so depend's bounded gate must
-- recheck the endpoint rather than preserve a dependency on finished history.
local function test_depend_prepared_before_blocker_done_is_refused()
  local root, left, right = seeded("fence-depend-done")
  local waiter = check.must(store.open(root))
  local waiting = check.must(store.load(waiter, left.id))
  waiting.depends_on = {right.id}
  write.set_op(waiter, "depend")
  write.set_bounded(waiter, true)
  assert(write.save(waiter, waiting, "depend before blocker done"))

  local finisher = check.must(store.open(root))
  local blocker = check.must(store.load(finisher, right.id))
  blocker.resolution = "completed"
  write.set_op(finisher, "done")
  assert(write.save(finisher, blocker, "finish blocker"))
  assert(publish.publish(finisher))

  local ok, err = publish.publish(waiter)
  assert(not ok and err:find("blocker is done", 1, true), err)
end

-- Once the dependency itself lands, finishing its blocker is valid and makes
-- the waiter pullable by derivation; the declared edge remains as history.
local function test_blocker_done_after_depend_lands_succeeds()
  local root, left, right = seeded("fence-done-after-depend")
  local waiter = check.must(store.open(root))
  local waiting = check.must(store.load(waiter, left.id))
  waiting.depends_on = {right.id}
  write.set_op(waiter, "depend")
  write.set_bounded(waiter, true)
  assert(write.save(waiter, waiting, "depend before blocker done"))
  assert(publish.publish(waiter))

  local finisher = check.must(store.open(root))
  local blocker = check.must(store.load(finisher, right.id))
  blocker.resolution = "completed"
  write.set_op(finisher, "done")
  assert(write.save(finisher, blocker, "finish blocker"))
  assert(publish.publish(finisher))
  local current = check.must(store.open(root))
  local got = check.must(store.load(current, left.id))
  assert(#got.depends_on == 1 and got.depends_on[1] == right.id)
  assert(not item.is_open(check.must(store.load(current, right.id))))
end
