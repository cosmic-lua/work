#!/usr/bin/env cosmic
-- `_work.readddl`'s `structure` view: the five SQL-derivable
-- whole-board audit findings, each checked against the Teal it stands
-- in for — `_work.gitfsck.structural_problems`'s dangling-parent,
-- second-parentless-item, stale-order, and duplicate-key findings, and
-- `_work.index`'s own `broken_chains` for a parent chain deeper than
-- 16. Split out of `_work.read_test` to keep that file under the line
-- cap. Runner mode (D29): every `test_*` below is enrolled by being
-- defined, not by being called.

local check = require("cosmic.check")
local idxmod = require("_work.index")
local irank = require("_work.index_rank")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local read = require("_work.read")
local readddl = require("_work.readddl")

local counter = 0

--- A fresh deterministic id.
--- @return string
local function fresh_id(): string
  counter = counter + 1
  return check.must(ksuid.encode(1700000000 + counter, ("\0"):rep(16)))
end

--- One valid item, `over` merged onto a bare title-only item.
--- @param over {string: any} Fields to set
--- @return item.Item
local function make(over: {string: any}): item.Item
  local t: {string: any} = {id = fresh_id(), title = "item"}
  for k, v in pairs(over or {}) do
    t[k] = v
  end
  return check.must(item.decode(t))
end

--- An index over `items` with `_work.index_rank` AND `_work.readddl`'s
--- views applied, in that order.
--- @param items {item.Item} The board
--- @return idxmod.Index
local function make_index(items: {item.Item}): idxmod.Index
  local idx = check.must(idxmod.open(items))
  check.must(irank.ensure_views(idx))
  check.must(readddl.ensure_views(idx))
  return idx
end

--- The one `structure` row of `kind` naming `id`, or nil when there is
--- none.
--- @param rows {read.StructureRow} Every finding
--- @param kind string The finding kind
--- @param id string The id it should name
--- @return read.StructureRow | nil
local function find(rows: {read.StructureRow}, kind: string, id: string): read.StructureRow | nil
  for _, r in ipairs(rows) do
    if r.kind == kind and r.id == id then
      return r
    end
  end
  return nil
end

local function test_dangling_parent()
  local board = make({})
  local orphan = make({parent = "does-not-exist"})
  local idx = make_index({board, orphan})
  local rows = check.must(read.structure(idx))
  local hit = find(rows, "dangling_parent", orphan.id)
  assert(hit ~= nil, "a parent naming no item is reported")
  assert(hit.detail:find("does-not-exist", 1, true) ~= nil, hit.detail)
  check.must(idxmod.close(idx))
end

local function test_second_root()
  local board = make({})
  local second = make({})
  local idx = make_index({board, second})
  local rows = check.must(read.structure(idx))
  -- The lower id is the canonical board (`_work.flow.find_board` walks
  -- `store.list`'s own id-ascending order and takes the first) — the
  -- higher id is the one flagged.
  local flagged = second
  if second.id < board.id then
    flagged = board
  end
  local hit = find(rows, "second_root", flagged.id)
  assert(hit ~= nil, "the second parentless item is reported")
  check.must(idxmod.close(idx))
end

local function test_stale_order_entry()
  local board = make({})
  local parent = make({parent = board.id})
  board.order = {parent.id}
  local real_child = make({parent = parent.id})
  local elsewhere = make({parent = board.id})
  -- `elsewhere` is a real item, but never reparented under `parent`.
  parent.order = {real_child.id, elsewhere.id}
  local idx = make_index({board, parent, real_child, elsewhere})
  local rows = check.must(read.structure(idx))
  local hit = find(rows, "stale_order", parent.id)
  assert(hit ~= nil, "an order entry naming a non-child is reported")
  assert(hit.detail:find(elsewhere.id, 1, true) ~= nil, hit.detail)
  check.must(idxmod.close(idx))
end

local function test_duplicate_key_is_unreachable_through_the_ordinary_load()
  -- `one_open_item_per_key` (`_work.indexddl`) already refuses a
  -- second OPEN item sharing a key at load — `_work.index`'s own
  -- `key_duplicates` states this is why IT always reports empty too.
  -- `structure`'s `duplicate_key` kind is the same live check on the
  -- same invariant, kept for the same reason, and pinned here as
  -- never firing through this path rather than asserted to catch a
  -- violation this schema does not let land in the first place.
  local board = make({})
  local outcome = make({parent = board.id})
  board.order = {outcome.id}
  local a = make({parent = outcome.id, key = "lane-x"})
  local b = make({parent = outcome.id, key = "lane-x"})
  local idx = check.must(idxmod.open({board, outcome, a, b}))
  check.must(irank.ensure_views(idx))
  check.must(readddl.ensure_views(idx))
  assert(#idxmod.problems(idx) == 1, "the second row is refused at load, not silently dropped")
  local rows = check.must(read.structure(idx))
  assert(find(rows, "duplicate_key", a.id) == nil, "unreachable this way")
  assert(find(rows, "duplicate_key", b.id) == nil, "unreachable this way")
  check.must(idxmod.close(idx))
end

local function test_deep_chain()
  local board = make({})
  local outcome = make({parent = board.id})
  board.order = {outcome.id}
  local cur = outcome.id
  local items: {item.Item} = {board, outcome}
  -- 15 containers puts the leaf at depth 17 — past the 16-hop bound.
  for _ = 1, 15 do
    local c = make({parent = cur})
    items[#items + 1] = c
    cur = c.id
  end
  local leaf = make({parent = cur})
  items[#items + 1] = leaf
  local idx = make_index(items)
  local rows = check.must(read.structure(idx))
  assert(find(rows, "deep_chain", leaf.id) ~= nil,
    "a chain past the 16-hop bound is reported")
  -- Nothing shallower on the same chain is flagged.
  assert(find(rows, "deep_chain", outcome.id) == nil, "the outcome itself is well within bound")
  check.must(idxmod.close(idx))
end

local function test_a_healthy_board_reports_nothing()
  local board = make({})
  local outcome = make({parent = board.id})
  board.order = {outcome.id}
  local kid = make({parent = outcome.id})
  local idx = make_index({board, outcome, kid})
  local rows = check.must(read.structure(idx))
  assert(#rows == 0, ("wanted no findings, got %d"):format(#rows))
  check.must(idxmod.close(idx))
end
