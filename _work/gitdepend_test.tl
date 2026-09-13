#!/usr/bin/env cosmic
-- `depend`/`undepend`: the one verb pair that declares which items an
-- item may not START before. Every case here runs against a fixture
-- board (`_work.fixture`), never the live one — the live board still
-- reads an older tree format than the one these fields live in.

local check = require("cosmic.check")
local fixture = require("_work.fixture")
local gitdepend = require("_work.gitdepend")
local gitdone = require("_work.gitdone")
local item = require("_work.item")
local store = require("_work.store")

local init_state_repo = fixture.init_state_repo
local file_item = fixture.file_item
local root_with_leaf = fixture.root_with_leaf

--- One item's `depends_on`, read back off the board rather than off the
--- record the verb held: the point of every assertion here is that the
--- ref moved.
--- @param s store.Store The store
--- @param id string The waiter
--- @return {string} Its declared dependencies
local function declared(s: store.Store, id: string): {string}
  return check.must(store.load(s, id)).depends_on or {}
end

-- The happy path: the edge lands on the WAITER's ref and nothing else
-- moves, because `depends_on` lives on the waiter.
local function test_depend_writes_the_waiters_ref_only()
  local s = init_state_repo("depend-write")
  local root, waiter = root_with_leaf(s)
  local blocker = file_item(s, "the blocker", root)
  local before = fixture.commits(s)
  assert(gitdepend.cmd_depend(s, waiter, blocker) == 0, "depend should land")
  local deps = declared(s, waiter)
  assert(#deps == 1 and deps[1] == blocker,
    "the waiter declares it: " .. table.concat(deps, ","))
  assert(#declared(s, blocker) == 0, "the blocker learns nothing")
  assert(fixture.commits(s) > before, "one commit landed")
end

-- A second dependency joins the first rather than replacing it: the
-- field is a set, and the verb only ever adds one edge.
local function test_a_second_dependency_joins_the_first()
  local s = init_state_repo("depend-two")
  local root, waiter = root_with_leaf(s)
  local first = file_item(s, "first blocker", root)
  local second = file_item(s, "second blocker", root)
  assert(gitdepend.cmd_depend(s, waiter, first) == 0)
  assert(gitdepend.cmd_depend(s, waiter, second) == 0)
  local deps = declared(s, waiter)
  assert(#deps == 2 and deps[1] == first and deps[2] == second,
    "both, in declared order: " .. table.concat(deps, ","))
end

-- Re-declaring an edge already present is a success that writes
-- nothing: the state asked for is already the state on the board.
local function test_an_existing_dependency_writes_nothing()
  local s = init_state_repo("depend-noop")
  local root, waiter = root_with_leaf(s)
  local blocker = file_item(s, "the blocker", root)
  assert(gitdepend.cmd_depend(s, waiter, blocker) == 0)
  local before = fixture.commits(s)
  assert(gitdepend.cmd_depend(s, waiter, blocker) == 0,
    "a dependency already present is a success")
  assert(fixture.commits(s) == before, "and writes nothing")
  assert(#declared(s, waiter) == 1, "no duplicate entry")
end

-- An item cannot depend on itself: the degenerate cycle, refused
-- before the board is even read.
local function test_self_dependency_refuses()
  local s = init_state_repo("depend-self")
  local _root, waiter = root_with_leaf(s)
  assert(gitdepend.cmd_depend(s, waiter, waiter) ~= 0,
    "an item cannot depend on itself")
  assert(#declared(s, waiter) == 0, "and nothing was written")
end

-- Either side naming no item refuses, rather than declaring an edge to
-- nowhere.
local function test_a_missing_item_on_either_side_refuses()
  local s = init_state_repo("depend-missing")
  local _root, waiter = root_with_leaf(s)
  local absent = "3HyArM3A3zHuRxn3VYCvKmUZ7KW"
  assert(gitdepend.cmd_depend(s, waiter, absent) ~= 0, "no blocker, no edge")
  assert(gitdepend.cmd_depend(s, absent, waiter) ~= 0, "no waiter, no edge")
  assert(#declared(s, waiter) == 0, "and nothing was written")
end

-- A finished item's dependencies are history: neither side of a done
-- pair is a repair target, the same rule `rank` holds a done item to.
local function test_a_done_item_on_either_side_refuses()
  local s = init_state_repo("depend-done")
  local root, waiter = root_with_leaf(s)
  local blocker = file_item(s, "the blocker", root)
  local finished = file_item(s, "already finished", root)
  assert(gitdone.cmd_done(s, finished, "not-planned", false, "") == 0,
    "the fixture item should finish")
  assert(gitdepend.cmd_depend(s, waiter, finished) ~= 0,
    "a done blocker is not a dependency to declare")
  assert(gitdepend.cmd_depend(s, finished, blocker) ~= 0,
    "a done waiter's dependencies are history")
  assert(#declared(s, waiter) == 0, "and nothing was written")
end

-- A two-hop cycle: A waits on B, B waits on C, and C may not then wait
-- on A. The refusal names the path it would have closed, so the reader
-- can see which edge to withdraw instead.
local function test_a_two_hop_cycle_refuses_and_names_the_path()
  local s = init_state_repo("depend-cycle")
  local root, a = root_with_leaf(s)
  local b = file_item(s, "b", root)
  local c = file_item(s, "c", root)
  assert(gitdepend.cmd_depend(s, a, b) == 0, "a waits on b")
  assert(gitdepend.cmd_depend(s, b, c) == 0, "b waits on c")
  assert(gitdepend.cmd_depend(s, c, a) ~= 0,
    "c waiting on a would close a two-hop cycle")
  assert(#declared(s, c) == 0, "and nothing was written")
  -- The one-hop case is the same walk with one fewer step.
  assert(gitdepend.cmd_depend(s, b, a) ~= 0,
    "b waiting on a would close a one-hop cycle")
end

-- `undepend` removes exactly the edge named and leaves the rest.
local function test_undepend_removes_only_the_named_edge()
  local s = init_state_repo("undepend")
  local root, waiter = root_with_leaf(s)
  local first = file_item(s, "first blocker", root)
  local second = file_item(s, "second blocker", root)
  assert(gitdepend.cmd_depend(s, waiter, first) == 0)
  assert(gitdepend.cmd_depend(s, waiter, second) == 0)
  assert(gitdepend.cmd_undepend(s, waiter, first) == 0, "it should withdraw")
  local deps = declared(s, waiter)
  assert(#deps == 1 and deps[1] == second,
    "only the named edge went: " .. table.concat(deps, ","))
end

-- Withdrawing an edge that is not there is a success that writes
-- nothing, the mirror of re-declaring one that is.
local function test_undepend_of_an_absent_edge_writes_nothing()
  local s = init_state_repo("undepend-noop")
  local root, waiter = root_with_leaf(s)
  local blocker = file_item(s, "the blocker", root)
  local before = fixture.commits(s)
  assert(gitdepend.cmd_undepend(s, waiter, blocker) == 0,
    "an absent dependency is a success")
  assert(fixture.commits(s) == before, "and writes nothing")
end

-- `--force` with no `--why` is refused on both verbs before anything is
-- read, the same audit rule every other mutation carries.
local function test_force_without_why_refuses()
  local s = init_state_repo("depend-force")
  local root, waiter = root_with_leaf(s)
  local blocker = file_item(s, "the blocker", root)
  assert(gitdepend.cmd_depend(s, waiter, blocker, nil, true, "") ~= 0,
    "--force needs --why")
  assert(gitdepend.cmd_undepend(s, waiter, blocker, nil, true, "") ~= 0,
    "--force needs --why on undepend too")
  assert(#declared(s, waiter) == 0, "and nothing was written")
end

-- The edge survives a round trip through the board's own decoder: the
-- field is one of the three declared lists, space-joined in `meta`.
local function test_the_edge_round_trips_through_decode()
  local s = init_state_repo("depend-roundtrip")
  local root, waiter = root_with_leaf(s)
  local blocker = file_item(s, "the blocker", root)
  assert(gitdepend.cmd_depend(s, waiter, blocker) == 0)
  local all = check.must(store.list(s))
  local back = item.by_id(all)[waiter]
  assert(back ~= nil and #(back.depends_on or {}) == 1
    and back.depends_on[1] == blocker, "the listed item carries it")
  assert(#item.problems(back) == 0, "and it is valid")
end
