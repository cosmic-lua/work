#!/usr/bin/env cosmic
-- `_work.index` is derived and rebuildable, so what pins it is
-- agreement with the Lua it stands in for: `problems` reports a
-- SUPERSET of `_work.flow.graph_problems`'s findings on every fixture
-- board these tests build, and the `state`/`substate` views agree with
-- `_work.flow` on every item. The STRICT-schema house defaults (typed
-- columns, WITHOUT ROWID text keys, foreign keys on, closed
-- vocabularies) are pinned directly against the real connection.

local check = require("cosmic.check")
local flow = require("_work.flow")
local idxmod = require("_work.index")
local item = require("_work.item")
local ksuid = require("_work.ksuid")

local counter = 0

--- A fresh deterministic id; later calls sort later, matching live
--- KSUID behavior.
local function fresh_id(): string
  counter = counter + 1
  return check.must(ksuid.encode(1700000000 + counter, ("\0"):rep(16)))
end

--- One valid item, `item.decode`d so every test board is exactly what
--- a real load would carry (zero-filled fields, `decode_problems`
--- possibly attached — decode never fails on a content problem).
local function make(over: {string: any}): item.Item
  local t: {string: any} = {id = fresh_id(), title = "item"}
  for k, v in pairs(over or {}) do
    t[k] = v
  end
  return check.must(item.decode(t))
end

--- Whether some index problem line names the same item as `flow_line`
--- (its leading `id:` token) and reports the same kind of finding —
--- "does not exist", "broken or cyclic", or an ambiguous cycle. The
--- wording map this test asserts: `_work.index`'s messages are written
--- to match `_work.flow`'s for exactly these three findings.
--- @param idx_problems {string} Index-reported problem lines
--- @param flow_line string One flow-reported problem line
--- @return boolean True when a matching index line exists
local function has_counterpart(idx_problems: {string}, flow_line: string): boolean
  local id = flow_line:match("^(%S+):")
  if id == nil then
    return false
  end
  local keyword = "does not exist"
  if flow_line:find("broken or cyclic", 1, true) then
    keyword = "broken or cyclic"
  elseif flow_line:find("ambiguous", 1, true) then
    keyword = "ambiguous"
  end
  for _, p in ipairs(idx_problems) do
    if p:find(id, 1, true) and p:find(keyword, 1, true) then
      return true
    end
  end
  return false
end

--- Assert `idxmod.problems` is a superset of `flow.graph_problems` for
--- one board, mapped by `has_counterpart`.
--- @param items {item.Item} The board
local function assert_superset(items: {item.Item})
  local flow_problems = flow.graph_problems(items)
  local idx = check.must(idxmod.open(items))
  local idx_problems = idxmod.problems(idx)
  for _, fp in ipairs(flow_problems) do
    assert(has_counterpart(idx_problems, fp),
      ("no index counterpart for flow problem: %s\nindex reported:\n  %s")
      :format(fp, table.concat(idx_problems, "\n  ")))
  end
  check.must(idxmod.close(idx))
end

local function test_superset_on_a_clean_board()
  local goal = make({})
  local epic = make({parent = goal.id})
  local kid = make({parent = epic.id})
  assert_superset({goal, epic, kid})
end

local function test_superset_on_a_dangling_parent()
  local goal = make({})
  local finding = make({})
  local orphan = make({parent = fresh_id()})
  local epic = make({parent = goal.id})
  local kid = make({parent = epic.id})
  assert_superset({goal, finding, orphan, epic, kid})
end

local function test_superset_on_a_broken_chain_past_the_direct_parent()
  local a = make({parent = fresh_id()})
  local b = make({parent = a.id})
  assert_superset({a, b})
end

local function test_superset_on_a_priority_cycle()
  local a = make({})
  local b = make({beats = a.id})
  a.beats = {b.id}
  assert_superset({a, b})
end

local function test_superset_on_a_two_level_cycle_and_a_container()
  local top = make({})
  local mid = make({parent = top.id})
  local leaf1 = make({parent = mid.id})
  local leaf2 = make({parent = mid.id, resolution = "completed"})
  local a = make({})
  local b = make({beats = a.id})
  a.beats = {b.id}
  assert_superset({top, mid, leaf1, leaf2, a, b})
end

--- One board mixing every role and state this file's other tests
--- exercise, shared by the state/substate agreement test below.
--- @return {item.Item} The board
local function mixed_board(): {item.Item}
  local goal = make({})
  local todo = make({parent = goal.id})
  local building = make({parent = goal.id, claim = "s1"})
  local reviewing = make({parent = goal.id, claim = "s1", pr = 4})
  local reworking = make({parent = goal.id, claim = "s1", pr = 5,
      verdict = "request changes"})
  local accepted = make({parent = goal.id, claim = "s1", pr = 6,
      verdict = "accept"})
  local handed = make({parent = goal.id, claim = "s1",
      result = ("ab"):rep(32)})
  local done = make({parent = goal.id, resolution = "completed"})
  local capture = make({})
  return {goal, todo, building, reviewing, reworking, accepted, handed,
    done, capture}
end

local function test_state_and_substate_views_agree_with_flow()
  local items = mixed_board()
  local idx = check.must(idxmod.open(items))
  for _, it in ipairs(items) do
    local want_state = "todo"
    if not item.is_open(it) then
      want_state = "ended"
    elseif flow.is_doing(it) then
      want_state = "doing"
    end
    local row = check.must(idx.db:query_one(
        "SELECT state FROM state WHERE id = ?", {it.id}))
    assert(row.state == want_state,
      ("%s: state %s, wanted %s"):format(it.id, tostring(row.state), want_state))
    local srow = check.must(idx.db:query_one(
        "SELECT substate FROM substate WHERE id = ?", {it.id}))
    assert(srow.substate == flow.substate(it),
      ("%s: substate %s, wanted %s"):format(it.id, tostring(srow.substate),
        flow.substate(it)))
  end
  check.must(idxmod.close(idx))
end

-- STRICT / WITHOUT ROWID / foreign-key house defaults, pinned against
-- the real connection `open` builds — not just documented.

local function test_foreign_keys_are_on()
  local idx = check.must(idxmod.open({make({})}))
  local row = check.must(idx.db:query_one("PRAGMA foreign_keys"))
  assert(row.foreign_keys == 1, "foreign keys must be enforced")
  check.must(idxmod.close(idx))
end

local function test_strict_refuses_a_wrong_typed_column()
  local idx = check.must(idxmod.open({make({})}))
  local ok, err = idx.db:exec(
    "INSERT INTO items(id, title, pr) VALUES ('zzz', 'x', 'not a number')")
  assert(not ok, "a TEXT value in an INTEGER STRICT column must be refused")
  assert(err:find("INTEGER", 1, true), err)
  check.must(idxmod.close(idx))
end

local function test_foreign_key_refuses_a_nonexistent_parent()
  local idx = check.must(idxmod.open({make({})}))
  local ok, err = idx.db:exec(
    "INSERT INTO items(id, title, parent) VALUES ('zzz', 'x', 'nope')")
  assert(not ok, "a parent naming no item must be refused")
  assert(err:find("FOREIGN KEY", 1, true), err)
  check.must(idxmod.close(idx))
end

local function test_primary_key_refuses_a_duplicate_id()
  local it = make({})
  local idx = check.must(idxmod.open({it}))
  local ok, err = idx.db:exec("INSERT INTO items(id, title) VALUES (?, 'dup')",
    {it.id})
  assert(not ok, "a duplicate id must be refused")
  assert(err:find("UNIQUE", 1, true) or err:find("PRIMARY KEY", 1, true), err)
  check.must(idxmod.close(idx))
end

-- Views a caller reads instead of re-deriving role by hand.

local function test_roots_containers_and_workable()
  local top = make({})
  local mid = make({parent = top.id})
  local leaf = make({parent = mid.id})
  local capture = make({})
  local idx = check.must(idxmod.open({top, mid, leaf, capture}))
  local db = idx.db
  local function ids(sql: string): {string: boolean}
    local out: {string: boolean} = {}
    for row in assert(db:query(sql)) do
      local id = row.id as string -- cast: from any (sqlite row)
      out[id] = true
    end
    return out
  end
  local roots = ids("SELECT id FROM roots")
  assert(roots[top.id] and roots[capture.id] and not roots[mid.id],
    "roots are parentless items only")
  local containers = ids("SELECT id FROM containers")
  assert(containers[top.id] and containers[mid.id] and not containers[leaf.id],
    "containers are items with an open child")
  local workable = ids("SELECT id FROM workable")
  assert(workable[leaf.id] and not workable[mid.id] and not workable[top.id],
    "workable is open, parented, and childless")
  check.must(idxmod.close(idx))
end

local function test_lane_uniqueness_refuses_a_second_open_claim()
  local a = make({lane = "release.yml"})
  local b = make({lane = "release.yml"})
  local idx = check.must(idxmod.open({a, b}))
  local problems = idxmod.problems(idx)
  local text = table.concat(problems, "\n")
  assert(text:find("lane", 1, true) and text:find(b.id, 1, true), text)
  local n = check.must(idx.db:query_one("SELECT COUNT(*) AS n FROM items"))
  assert(n.n == 1, "only the first claimant's row lands")
  check.must(idxmod.close(idx))
end
