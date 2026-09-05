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
local sqlite = require("cosmic.sqlite")

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

local function test_dangling_parent_is_reported_by_problems_not_refused()
  local idx = check.must(idxmod.open({make({})}))
  local ok, err = idx.db:exec(
    "INSERT INTO items(id, title, parent) VALUES ('zzz', 'x', 'nope')")
  assert(ok, "parent carries no foreign key — the insert must succeed: "
    .. tostring(err))
  local problems = idxmod.problems(idx)
  local found = false
  for _, p in ipairs(problems) do
    if p:find("zzz", 1, true) and p:find("parent nope does not exist", 1, true) then
      found = true
    end
  end
  assert(found, "a dangling parent is a problems() finding: "
    .. table.concat(problems, "; "))
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

-- An outcome with no children of its own is still not workable — it
-- is a direct child of the board, and decomposing it is triage's
-- answer, never a take's, matching `_work.flow.role`.
local function test_workable_excludes_a_childless_outcome()
  local board = make({})
  local outcome = make({parent = board.id})
  local leaf = make({parent = outcome.id})
  local idx = check.must(idxmod.open({board, outcome, leaf}))
  local db = idx.db
  local function ids(sql: string): {string: boolean}
    local out: {string: boolean} = {}
    for row in assert(db:query(sql)) do
      local id = row.id as string -- cast: from any (sqlite row)
      out[id] = true
    end
    return out
  end
  local workable = ids("SELECT id FROM workable")
  assert(not workable[outcome.id],
    "a childless outcome is still not workable: decomposing it is triage")
  assert(workable[leaf.id], "a leaf below the outcome level is workable")
  check.must(idxmod.close(idx))
end

-- Secondary indexes: `EXPLAIN QUERY PLAN` names them by name, pinned
-- against the real connection rather than trusted to the DDL comment.

--- Every `detail` line an `EXPLAIN QUERY PLAN` over `sql` reports,
--- concatenated with newlines — one string a caller can `:find` an
--- index name in without hand-rolling the loop each time.
--- @param db sqlite.Database The connection
--- @param sql string A statement to explain (an `EXPLAIN QUERY PLAN
--- ...` prefix is added by the caller's own query, not this helper)
--- @return string Every plan line, newline-joined
local function plan_of(db: sqlite.Database, sql: string): string
  local lines: {string} = {}
  for row in assert(db:query("EXPLAIN QUERY PLAN " .. sql)) do
    lines[#lines + 1] = row.detail as string -- cast: from any (sqlite row)
  end
  return table.concat(lines, "\n")
end

local function test_workable_view_uses_the_parent_index()
  local idx = check.must(idxmod.open({make({})}))
  local plan = plan_of(idx.db, "SELECT * FROM workable")
  assert(plan:find("items_parent", 1, true),
    "workable's plan does not name items_parent:\n" .. plan)
  check.must(idxmod.close(idx))
end

-- Vocabulary equality: the DDL's `verdict`/`resolution` CHECK lists
-- must name exactly `_work.item`'s vocabularies, so a new word cannot
-- become a refused row without both being updated together.

--- The quoted values inside `column`'s `CHECK(column IN (...))` clause
--- in `idxmod.DDL`, as a set.
--- @param column string The column name (`verdict` or `resolution`)
--- @return {string: boolean} The values the DDL admits
local function ddl_check_values(column: string): {string: boolean}
  local list = idxmod.DDL:match("CHECK%(" .. column .. " IN %((.-)%)%)")
  assert(list, ("no CHECK IN(...) clause found for %s in the DDL"):format(column))
  local out: {string: boolean} = {}
  for v in list:gmatch("'([^']*)'") do
    out[v] = true
  end
  return out
end

--- Assert two vocabularies name exactly the same values.
--- @param got {string: boolean} What the DDL admits
--- @param want {string: boolean} What `_work.item` admits
--- @param label string Named in a mismatch's message
local function assert_same_vocabulary(got: {string: boolean},
    want: {string: boolean}, label: string)
  for v in pairs(got) do
    assert(want[v], ("DDL %s admits %q, which item.tl does not"):format(label, v))
  end
  for v in pairs(want) do
    assert(got[v], ("item.tl %s admits %q, which the DDL does not"):format(label, v))
  end
end

local function test_ddl_verdict_and_resolution_match_item_vocabularies()
  assert_same_vocabulary(ddl_check_values("verdict"), item.VERDICTS, "verdict")
  assert_same_vocabulary(ddl_check_values("resolution"), item.RESOLUTIONS,
    "resolution")
end

local function test_key_uniqueness_refuses_a_second_open_claim()
  local a = make({key = "release.yml"})
  local b = make({key = "release.yml"})
  local idx = check.must(idxmod.open({a, b}))
  local problems = idxmod.problems(idx)
  local text = table.concat(problems, "\n")
  assert(text:find("key", 1, true) and text:find(b.id, 1, true), text)
  local n = check.must(idx.db:query_one("SELECT COUNT(*) AS n FROM items"))
  assert(n.n == 1, "only the first claimant's row lands")
  check.must(idxmod.close(idx))
end
