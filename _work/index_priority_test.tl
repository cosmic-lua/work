#!/usr/bin/env cosmic
-- Proves `_work.index_priority`'s SQL views equal `_work.priority`'s
-- Lua derivation: same placement (band, own, placed), same order, same
-- cycle set, same unplaced set — on every fixture board below (mirrors
-- of `_work.priority_test`'s own scenarios) and on a generated random
-- board with an injected cycle. None of these boards carry
-- `blocked_by` edges — see `_work.index_priority`'s header for why
-- that is exactly what makes the SQL order (band, own, id; no lift,
-- no unblocks) equal `_work.priority.sorted`'s unseeded order rather
-- than merely approximate it.

local check = require("cosmic.check")
local idxmod = require("_work.index")
local iprio = require("_work.index_priority")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local prio = require("_work.priority")

local counter = 0

--- A fresh deterministic id; later calls sort later, matching live
--- KSUID behavior.
local function fresh_id(): string
  counter = counter + 1
  return check.must(ksuid.encode(1700000000 + counter, ("\0"):rep(16)))
end

--- One valid item.
local function make(over: {string: any}): item.Item
  local t: {string: any} = {id = fresh_id(), title = "item"}
  for k, v in pairs(over or {}) do
    t[k] = v
  end
  return check.must(item.decode(t))
end

--- Every board scenario `_work.priority_test` pins for `own`/`band`
--- (transitivity, band inheritance, an unplaced ancestor, a dangling
--- edge, two leaves refining a band, and age-order peers), combined
--- into one board — each scenario's ids are fresh, so combining them
--- changes no scenario's own placement.
--- @return {item.Item} The board
local function fixture_board(): {item.Item}
  local out: {item.Item} = {}
  local function add(...: item.Item)
    for _, i in ipairs({...}) do
      out[#out + 1] = i
    end
  end

  -- Transitivity closes an untested pair.
  local c = make({})
  local b = make({beats = c.id})
  local a = make({beats = b.id})
  add(c, b, a)

  -- A comparison at height places a leaf two levels down.
  local lesser = make({})
  local top = make({beats = lesser.id})
  local mid = make({parent = top.id})
  local leaf = make({parent = mid.id})
  add(lesser, top, mid, leaf)

  -- An item no edge reaches, and its child, are both unplaced.
  local lonely = make({})
  local kid = make({parent = lonely.id})
  add(lonely, kid)

  -- A `beats` entry naming no item is not an edge.
  local dangling = make({beats = fresh_id()})
  add(dangling)

  -- Two leaves inheriting DIFFERENT bands, compared directly: the
  -- comparison must refine standing within each band, never cross it.
  local lesser_a = make({})
  local top_a = make({beats = lesser_a.id})
  local leaf_a = make({parent = top_a.id, beats = fresh_id()})
  local z1 = make({})
  local z2 = make({beats = z1.id})
  local z3 = make({beats = z2.id})
  local top_b = make({beats = z3.id})
  local leaf_b = make({parent = top_b.id})
  leaf_a.beats = {leaf_b.id}
  add(lesser_a, top_a, leaf_a, z1, z2, z3, top_b, leaf_b)

  -- Peers in one band with no comparison between them fall back to age.
  local lesser_p = make({})
  local top_p = make({beats = lesser_p.id})
  local older = make({parent = top_p.id})
  local newer = make({parent = top_p.id})
  add(lesser_p, top_p, older, newer)

  return out
end

--- A board holding a two-item priority cycle, isolated so the cycle
--- assertions do not have to pick it out of a larger set.
--- @return {item.Item} The board
local function cycle_board(): {item.Item}
  local x = make({})
  local y = make({beats = x.id})
  x.beats = {y.id}
  return {x, y}
end

--- Assert the SQL and Lua derivations agree on `items`: same order,
--- same placement per id, same cycle set, same unplaced set.
--- @param items {item.Item} The board
local function assert_matches(items: {item.Item})
  local idx = check.must(idxmod.open(items))
  check.must(iprio.ensure_views(idx))

  local lua_pos = prio.positions(items)
  local lua_order = prio.sorted(items, lua_pos)
  local lua_order_ids: {string} = {}
  for _, i in ipairs(lua_order) do
    lua_order_ids[#lua_order_ids + 1] = i.id
  end
  local sql_order = iprio.order_ids(idx)
  assert(table.concat(sql_order, " ") == table.concat(lua_order_ids, " "),
    ("order mismatch\nsql:  %s\nlua:  %s"):format(
      table.concat(sql_order, " "), table.concat(lua_order_ids, " ")))

  for _, it in ipairs(items) do
    local lua_placed = prio.is_placed(lua_pos, it.id)
    local lua_band, lua_own = prio.key_of(lua_pos, it.id)
    local sql_placed, sql_band, sql_own = iprio.position_of(idx, it.id)
    assert(sql_placed == lua_placed,
      ("%s: placed sql=%s lua=%s"):format(it.id, tostring(sql_placed),
        tostring(lua_placed)))
    assert(sql_band == lua_band,
      ("%s: band sql=%d lua=%d"):format(it.id, sql_band, lua_band))
    assert(sql_own == lua_own,
      ("%s: own sql=%d lua=%d"):format(it.id, sql_own, lua_own))
  end

  local lua_cycle: {string: boolean} = {}
  for _, p in ipairs(prio.cycle_problems(items)) do
    local id = p:match("^(%S+):")
    if id then
      lua_cycle[id] = true
    end
  end
  local sql_cycle = iprio.cycle_ids(idx)
  for id in pairs(lua_cycle) do
    assert(sql_cycle[id], ("%s: lua reports a cycle, sql does not"):format(id))
  end
  for id in pairs(sql_cycle) do
    assert(lua_cycle[id], ("%s: sql reports a cycle, lua does not"):format(id))
  end

  local lua_unplaced: {string: boolean} = {}
  for _, it in ipairs(items) do
    if not prio.is_placed(lua_pos, it.id) then
      lua_unplaced[it.id] = true
    end
  end
  local sql_unplaced = iprio.unplaced_ids(idx)
  for id in pairs(lua_unplaced) do
    assert(sql_unplaced[id], ("%s: lua says unplaced, sql does not"):format(id))
  end
  for id in pairs(sql_unplaced) do
    assert(lua_unplaced[id], ("%s: sql says unplaced, lua does not"):format(id))
  end

  check.must(idxmod.close(idx))
end

local function test_sql_matches_lua_on_the_fixture_board()
  assert_matches(fixture_board())
end

local function test_sql_matches_lua_on_a_cycle_board()
  assert_matches(cycle_board())
end

local function test_sql_matches_lua_on_the_fixture_and_a_cycle_together()
  local items = fixture_board()
  for _, i in ipairs(cycle_board()) do
    items[#items + 1] = i
  end
  assert_matches(items)
end

-- A deterministic LCG, seeded fixed: the random board must fail the
-- same way on every run for a failure to be diagnosable, and CI must
-- see the same board every time.
local seed = 20260904
local function rnd(n: integer): integer
  seed = (seed * 1103515245 + 12345) % 2147483648
  return seed % n
end

--- A board of `n` items with random parents (about a third are roots)
--- and random `beats` edges (about half the items name one, to an
--- earlier item so most chains stay short), plus one deliberately
--- injected 3-item cycle among early items.
--- @param n integer How many items
--- @return {item.Item} The board
local function random_board(n: integer): {item.Item}
  local items: {item.Item} = {}
  for k = 1, n do
    local parent = ""
    if k > 1 and rnd(3) ~= 0 then
      parent = items[rnd(k - 1) + 1].id
    end
    local beats = ""
    if k > 3 and rnd(2) == 0 then
      beats = items[rnd(k - 1) + 1].id
    end
    items[#items + 1] = make({parent = parent, beats = beats})
  end
  -- Inject a cycle among the first three items, overriding whatever
  -- random edges they picked.
  items[1].beats = {items[2].id}
  items[2].beats = {items[3].id}
  items[3].beats = {items[1].id}
  return items
end

local function test_sql_matches_lua_on_a_random_board()
  local board = random_board(300)
  assert(#board == 300, "the generated board is the size asked for")
  assert_matches(board)
end
