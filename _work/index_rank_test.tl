#!/usr/bin/env cosmic
-- `_work.index_rank`'s `rank_path` view: root list order, sibling
-- positions, dense positions with a stale entry skipped, an item under
-- an unranked root reading unplaced and sorting after every placed
-- key, and `ORDER BY key, id` on a small mixed board matching
-- docs/design/order.md's rule. Runner mode (D29): every `test_*` below
-- is enrolled by being defined, not by being called.

local check = require("cosmic.check")
local idxmod = require("_work.index")
local irank = require("_work.index_rank")
local item = require("_work.item")
local ksuid = require("_work.ksuid")

local counter = 0

--- A fresh deterministic id; later calls sort later, matching live
--- KSUID behavior — the tests below rely on that for their "age order"
--- assertions.
--- @return string
local function fresh_id(): string
  counter = counter + 1
  return check.must(ksuid.encode(1700000000 + counter, ("\0"):rep(16)))
end

--- One valid item, `over` merged onto a bare title-only item.
--- @param over {string: any} Fields to set, e.g. `{parent = root.id}`
--- @return item.Item
local function make(over: {string: any}): item.Item
  local t: {string: any} = {id = fresh_id(), title = "item"}
  for k, v in pairs(over or {}) do
    t[k] = v
  end
  return check.must(item.decode(t))
end

--- An index over `items` with `root_order` loaded as the board's root
--- list and the rank views applied — `_work.index.open` plus
--- `insert_root_order` plus `_work.index_rank.ensure_views`, the setup
--- every test below shares.
--- @param items {item.Item} The board
--- @param root_order {string} The board's root ranking, in rank order
--- @return idxmod.Index
local function make_index(items: {item.Item}, root_order: {string}): idxmod.Index
  local idx = check.must(idxmod.open(items))
  check.must(idxmod.insert_root_order(idx.db, root_order))
  check.must(irank.ensure_views(idx))
  return idx
end

--- The exact 28-character field `_work.index_rank`'s view builds for a
--- POSITIONED level, so a test can assert on the real string instead of
--- reasoning about SQL padding by eye.
--- @param pos integer The dense position (1-based)
--- @return string The field, 28 characters
local function positioned_field(pos: integer): string
  local digits = tostring(pos)
  return "0" .. ("0"):rep(27 - #digits) .. digits
end

--- The exact 28-character field for an UNPOSITIONED level.
--- @param id string The level's own id (27 characters)
--- @return string The field, 28 characters
local function unpositioned_field(id: string): string
  return "1" .. id
end

local function test_root_list_order()
  local a = make({})
  local b = make({})
  local c = make({})
  local idx = make_index({a, b, c}, {c.id, a.id, b.id})

  local placed_a, key_a = irank.rank_of(idx, a.id)
  local placed_b, key_b = irank.rank_of(idx, b.id)
  local placed_c, key_c = irank.rank_of(idx, c.id)
  assert(placed_a and placed_b and placed_c, "every ranked root is placed")
  assert(key_c == positioned_field(1), key_c)
  assert(key_a == positioned_field(2), key_a)
  assert(key_b == positioned_field(3), key_b)

  local ids = irank.order_ids(idx)
  assert(table.concat(ids, " ") == table.concat({c.id, a.id, b.id}, " "),
    table.concat(ids, " "))
  check.must(idxmod.close(idx))
end

local function test_sibling_positions()
  local root = make({})
  local x = make({parent = root.id})
  local y = make({parent = root.id})
  local z = make({parent = root.id})
  root.order = {x.id, y.id, z.id}
  local idx = make_index({root, x, y, z}, {root.id})

  local root_field = positioned_field(1)
  local _px, key_x = irank.rank_of(idx, x.id)
  local _py, key_y = irank.rank_of(idx, y.id)
  local _pz, key_z = irank.rank_of(idx, z.id)
  assert(key_x == root_field .. "/" .. positioned_field(1), key_x)
  assert(key_y == root_field .. "/" .. positioned_field(2), key_y)
  assert(key_z == root_field .. "/" .. positioned_field(3), key_z)
  check.must(idxmod.close(idx))
end

local function test_dense_positions_skip_a_stale_entry()
  local root = make({})
  local x = make({parent = root.id})
  local y = make({parent = root.id})
  -- A real item, but never reparented under `root` — a stale entry:
  -- named in `root.order` without ever becoming `root`'s child.
  local stale = make({})
  root.order = {x.id, stale.id, y.id}
  local idx = make_index({root, x, y, stale}, {root.id})

  local root_field = positioned_field(1)
  local _px, key_x = irank.rank_of(idx, x.id)
  local _py, key_y = irank.rank_of(idx, y.id)
  -- `stale` sits at stored index 2 in `root.order`, but names no real
  -- child of `root`, so it earns no position at all and is skipped:
  -- `y`, stored at index 3, gets the DENSE position 2, not 3.
  assert(key_x == root_field .. "/" .. positioned_field(1), key_x)
  assert(key_y == root_field .. "/" .. positioned_field(2), key_y)
  check.must(idxmod.close(idx))
end

local function test_item_under_an_unranked_root_is_unplaced_and_sorts_last()
  local placed_root = make({})
  local unranked_root = make({})
  local kid = make({parent = unranked_root.id})
  -- Only `placed_root` is in the board's own list.
  local idx = make_index({placed_root, unranked_root, kid}, {placed_root.id})

  local placed_r, key_r = irank.rank_of(idx, unranked_root.id)
  local placed_k, key_k = irank.rank_of(idx, kid.id)
  assert(not placed_r, "a root absent from the board's list is not placed")
  assert(not placed_k, "and neither is anything under it")
  assert(key_r == unpositioned_field(unranked_root.id), key_r)

  local _placed_p, key_p = irank.rank_of(idx, placed_root.id)
  assert(key_p < key_r,
    ("a placed root's key sorts before an unranked one's: %s vs %s")
    :format(key_p, key_r))
  assert(key_p < key_k,
    ("...and before anything under an unranked root too: %s vs %s")
    :format(key_p, key_k))
  check.must(idxmod.close(idx))
end

-- One small board combining several scenarios: a positioned root with
-- a positioned child and two unpositioned ones (oldest first), beside
-- an unranked root with its own unpositioned child — reasoned out
-- field by field in the module's own header, then asserted here as
-- the one order `_work.index_rank.order_ids` must produce end to end.
local function test_order_by_key_then_id_matches_the_stated_rule()
  local r1 = make({}) -- ranked root, position 1
  local r2 = make({}) -- unranked root
  local c1 = make({parent = r1.id}) -- r1's ranked child, position 1
  local older_unranked = make({parent = r1.id}) -- r1's unranked children,
  local newer_unranked = make({parent = r1.id}) -- oldest created first
  r1.order = {c1.id}
  local grandkid = make({parent = r2.id}) -- unranked, under an unranked root

  local idx = make_index(
    {r1, r2, c1, older_unranked, newer_unranked, grandkid}, {r1.id})
  local got = irank.order_ids(idx)
  local want = {r1.id, c1.id, older_unranked.id, newer_unranked.id, r2.id,
    grandkid.id}
  assert(table.concat(got, " ") == table.concat(want, " "),
    ("got:  %s\nwant: %s"):format(table.concat(got, " "), table.concat(want, " ")))
  check.must(idxmod.close(idx))
end
