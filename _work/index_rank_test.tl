#!/usr/bin/env cosmic
-- `_work.index_rank`'s `rank_path` view: the board's own `order`
-- ranking its outcomes, sibling positions, dense positions with a
-- stale entry skipped, an item under an unranked outcome reading
-- unplaced and sorting after every placed key, and `ORDER BY key, id`
-- on a small mixed board matching docs/design/order.md's rule.
-- Runner mode (D29): every `test_*` below is enrolled by being
-- defined, not by being called.

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
--- @param over {string: any} Fields to set, e.g. `{parent = board.id}`
--- @return item.Item
local function make(over: {string: any}): item.Item
  local t: {string: any} = {id = fresh_id(), title = "item"}
  for k, v in pairs(over or {}) do
    t[k] = v
  end
  return check.must(item.decode(t))
end

--- An index over `items` with the rank views applied — `_work.index.open`
--- plus `_work.index_rank.ensure_views`, the setup every test below
--- shares. The board's own outcome ranking rides on the board ITEM's
--- own `order` field, already in `items` — there is no separate call
--- to load it.
--- @param items {item.Item} The board
--- @return idxmod.Index
local function make_index(items: {item.Item}): idxmod.Index
  local idx = check.must(idxmod.open(items))
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

local function test_the_board_carries_an_empty_key()
  local board = make({})
  local a = make({parent = board.id})
  board.order = {a.id}
  local idx = make_index({board, a})
  local placed, key = irank.rank_of(idx, board.id)
  assert(placed, "the board is trivially placed — it has no outcome to fail")
  assert(key == "", "the board's own key is empty: " .. key)
  check.must(idxmod.close(idx))
end

local function test_outcome_ranking_from_the_boards_own_order()
  local board = make({})
  local a = make({parent = board.id})
  local b = make({parent = board.id})
  local c = make({parent = board.id})
  board.order = {c.id, a.id, b.id}
  local idx = make_index({board, a, b, c})

  local placed_a, key_a = irank.rank_of(idx, a.id)
  local placed_b, key_b = irank.rank_of(idx, b.id)
  local placed_c, key_c = irank.rank_of(idx, c.id)
  assert(placed_a and placed_b and placed_c, "every ranked outcome is placed")
  assert(key_c == positioned_field(1), key_c)
  assert(key_a == positioned_field(2), key_a)
  assert(key_b == positioned_field(3), key_b)

  local ids = irank.order_ids(idx)
  assert(table.concat(ids, " ") == table.concat({board.id, c.id, a.id, b.id}, " "),
    table.concat(ids, " "))
  check.must(idxmod.close(idx))
end

local function test_sibling_positions()
  local board = make({})
  local root = make({parent = board.id})
  local x = make({parent = root.id})
  local y = make({parent = root.id})
  local z = make({parent = root.id})
  root.order = {x.id, y.id, z.id}
  board.order = {root.id}
  local idx = make_index({board, root, x, y, z})

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
  local board = make({})
  local root = make({parent = board.id})
  local x = make({parent = root.id})
  local y = make({parent = root.id})
  -- A real item, but never reparented under `root` — a stale entry:
  -- named in `root.order` without ever becoming `root`'s child.
  local stale = make({parent = board.id})
  root.order = {x.id, stale.id, y.id}
  board.order = {root.id}
  local idx = make_index({board, root, x, y, stale})

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

local function test_item_under_an_unranked_outcome_is_unplaced_and_sorts_last()
  local board = make({})
  local placed_outcome = make({parent = board.id})
  local unranked_outcome = make({parent = board.id})
  local kid = make({parent = unranked_outcome.id})
  -- Only `placed_outcome` is in the board's own `order`.
  board.order = {placed_outcome.id}
  local idx = make_index({board, placed_outcome, unranked_outcome, kid})

  local placed_r, key_r = irank.rank_of(idx, unranked_outcome.id)
  local placed_k, key_k = irank.rank_of(idx, kid.id)
  assert(not placed_r, "an outcome absent from the board's list is not placed")
  assert(not placed_k, "and neither is anything under it")
  assert(key_r == unpositioned_field(unranked_outcome.id), key_r)

  local _placed_p, key_p = irank.rank_of(idx, placed_outcome.id)
  assert(key_p < key_r,
    ("a placed outcome's key sorts before an unranked one's: %s vs %s")
    :format(key_p, key_r))
  assert(key_p < key_k,
    ("...and before anything under an unranked outcome too: %s vs %s")
    :format(key_p, key_k))
  check.must(idxmod.close(idx))
end

-- One small board combining several scenarios: the board itself, a
-- positioned outcome with a positioned child and two unpositioned
-- ones (oldest first), beside an unranked outcome with its own
-- unpositioned child — reasoned out field by field in the module's
-- own header, then asserted here as the one order
-- `_work.index_rank.order_ids` must produce end to end.
local function test_order_by_key_then_id_matches_the_stated_rule()
  local board = make({})
  local r1 = make({parent = board.id}) -- ranked outcome, position 1
  local r2 = make({parent = board.id}) -- unranked outcome
  local c1 = make({parent = r1.id}) -- r1's ranked child, position 1
  local older_unranked = make({parent = r1.id}) -- r1's unranked children,
  local newer_unranked = make({parent = r1.id}) -- oldest created first
  r1.order = {c1.id}
  local grandkid = make({parent = r2.id}) -- unranked, under an unranked outcome
  board.order = {r1.id}

  local idx = make_index(
    {board, r1, r2, c1, older_unranked, newer_unranked, grandkid})
  local got = irank.order_ids(idx)
  local want = {board.id, r1.id, c1.id, older_unranked.id, newer_unranked.id,
    r2.id, grandkid.id}
  assert(table.concat(got, " ") == table.concat(want, " "),
    ("got:  %s\nwant: %s"):format(table.concat(got, " "), table.concat(want, " ")))
  check.must(idxmod.close(idx))
end
