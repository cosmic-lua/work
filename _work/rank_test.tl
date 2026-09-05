-- The rank-path derivation: an item's rank is a path down from its
-- root, and every level of that path is a position in a list the
-- level above holds. These pin the rule directly.

local check = require("cosmic.check")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local rank = require("_work.rank")

local counter = 0

--- A fresh deterministic id; later calls sort later, so creation order
--- is age order exactly as live ksuids behave.
local function fresh_id(): string
  counter = counter + 1
  return check.must(ksuid.encode(1700000000 + counter, ("\0"):rep(16)))
end

--- One valid item, `order`/`beats`/etc space-joined the way `decode`
--- expects.
local function make(over: {string: any}): item.Item
  local t: {string: any} = {id = fresh_id(), title = "item"}
  for k, v in pairs(over or {}) do
    t[k] = v
  end
  return check.must(item.decode(t))
end

--- The ids of a list, in order.
local function ids(list: {item.Item}): {string}
  local out: {string} = {}
  for _, i in ipairs(list) do
    out[#out + 1] = i.id
  end
  return out
end

local function test_root_ordering_from_the_board_list()
  local a = make({})
  local b = make({})
  local c = make({})
  local items: {item.Item} = {a, b, c}
  local ranks = rank.positions(items, {b.id, c.id, a.id})
  assert(rank.is_ranked(ranks, a.id), "every root named in the list is ranked")
  local order = ids(rank.sorted(items, ranks))
  assert(order[1] == b.id and order[2] == c.id and order[3] == a.id,
    "roots sort by their position in the board's list: " .. table.concat(
      order, ","))
end

local function test_sibling_ordering()
  local top = make({})
  local first = make({parent = top.id})
  local second = make({parent = top.id})
  top.order = {second.id, first.id}
  local items: {item.Item} = {top, first, second}
  local ranks = rank.positions(items, {top.id})
  local order = ids(rank.sorted({first, second}, ranks))
  assert(order[1] == second.id and order[2] == first.id,
    "siblings sort by their position in the parent's list")
end

local function test_an_unpositioned_sibling_sorts_after_positioned_ones_by_age()
  local top = make({})
  local older = make({parent = top.id})
  local newer = make({parent = top.id})
  local positioned = make({parent = top.id})
  top.order = {positioned.id}
  local items: {item.Item} = {top, older, newer, positioned}
  local ranks = rank.positions(items, {top.id})
  local order = ids(rank.sorted({newer, older, positioned}, ranks))
  assert(order[1] == positioned.id,
    "the positioned sibling sorts first regardless of age")
  assert(order[2] == older.id and order[3] == newer.id,
    "unpositioned siblings fall back to age, oldest first: "
    .. table.concat(order, ","))
end

local function test_a_stale_entry_is_skipped_and_positions_stay_dense()
  local top = make({})
  local moved_away = fresh_id() -- named in the list, no longer a child
  local first = make({parent = top.id})
  local second = make({parent = top.id})
  top.order = {moved_away, first.id, moved_away, second.id}
  local items: {item.Item} = {top, first, second}
  local ranks = rank.positions(items, {top.id})
  local at = ranks[first.id]
  local bt = ranks[second.id]
  assert(at.chain[#at.chain].position == 0,
    "the stale entry consumes no slot: " .. tostring(at.chain[#at.chain]
      .position))
  assert(bt.chain[#bt.chain].position == 1,
    "so positions stay dense: " .. tostring(bt.chain[#bt.chain].position))
  local order = ids(rank.sorted({second, first}, ranks))
  assert(order[1] == first.id and order[2] == second.id,
    "and the two real children still sort by their real positions")
end

local function test_an_item_under_an_unranked_root_is_unranked_and_sorts_last()
  local ranked_root = make({})
  local unranked_root = make({})
  local under_ranked = make({parent = ranked_root.id})
  local under_unranked = make({parent = unranked_root.id})
  local items: {item.Item} = {ranked_root, unranked_root, under_ranked,
    under_unranked}
  local ranks = rank.positions(items, {ranked_root.id})
  assert(rank.is_ranked(ranks, under_ranked.id),
    "its root is in the board's list")
  assert(not rank.is_ranked(ranks, unranked_root.id),
    "a root absent from the list is triage")
  assert(not rank.is_ranked(ranks, under_unranked.id),
    "and so is everything under it")
  local order = ids(rank.sorted(items, ranks))
  assert(order[#order - 1] == unranked_root.id
    or order[#order] == unranked_root.id, "the unranked root sorts last")
  assert(order[4] == under_unranked.id or order[3] == under_unranked.id,
    "the unranked leaf sorts among the last two")
  assert(order[1] == ranked_root.id or order[1] == under_ranked.id,
    "a ranked item always sorts before an unranked one: " .. table.concat(
      order, ","))
end

--- `_work.rank`'s own `fnv32`, copied so this test can compute the
--- exact expected seeded order independently rather than guessing at
--- one.
--- @param text string The text to hash
--- @return integer The 32-bit hash
local function fnv32(text: string): integer
  local h = 2166136261
  for k = 1, #text do
    h = ((h ~ text:byte(k)) * 16777619) & 0xFFFFFFFF
  end
  return h
end

local function test_seed_changes_only_the_tie_among_unpositioned_peers()
  local top = make({})
  local a = make({parent = top.id})
  local b = make({parent = top.id})
  local c = make({parent = top.id})
  local items: {item.Item} = {top, a, b, c}
  local ranks = rank.positions(items, {top.id})
  local age_order = ids(rank.sorted({a, b, c}, ranks))
  assert(age_order[1] == a.id and age_order[2] == b.id
    and age_order[3] == c.id, "no seed keeps age order")

  local seed = "session-one"
  local expected: {item.Item} = {a, b, c}
  table.sort(expected, function(x: item.Item, y: item.Item): boolean
      local hx, hy = fnv32(seed .. x.id), fnv32(seed .. y.id)
      if hx ~= hy then
        return hx < hy
      end
      return x.id < y.id
    end)
  local seeded = ids(rank.sorted({a, b, c}, ranks, seed))
  assert(table.concat(seeded, ",") == table.concat(ids(expected), ","),
    "the seeded order matches the hash of seed .. id: "
    .. table.concat(seeded, ","))

  -- Positioned items never move regardless of seed.
  top.order = {a.id, b.id, c.id}
  local placed = rank.positions(items, {top.id})
  local by_age = ids(rank.sorted({a, b, c}, placed))
  local by_seed = ids(rank.sorted({a, b, c}, placed, seed))
  assert(by_age[1] == a.id and by_age[2] == b.id and by_age[3] == c.id,
    "a positioned order is not a tie")
  assert(by_seed[1] == a.id and by_seed[2] == b.id and by_seed[3] == c.id,
    "so a seed changes nothing once siblings are positioned")
end

local function test_ancestor_before_descendant()
  local top = make({})
  local child = make({parent = top.id})
  local grandchild = make({parent = child.id})
  local items: {item.Item} = {top, child, grandchild}
  local ranks = rank.positions(items, {top.id})
  local order = ids(rank.sorted({grandchild, child, top}, ranks))
  assert(order[1] == top.id and order[2] == child.id
    and order[3] == grandchild.id,
    "each ancestor sorts before its own descendant: " .. table.concat(
      order, ","))
end

local function test_key_agrees_with_sorted_on_a_small_board()
  local root_a = make({})
  local root_b = make({})
  local a1 = make({parent = root_a.id})
  local a2 = make({parent = root_a.id})
  local b1 = make({parent = root_b.id})
  local stray = make({parent = root_a.id})
  root_a.order = {a2.id, a1.id}
  local items: {item.Item} = {root_a, root_b, a1, a2, b1, stray}
  local ranks = rank.positions(items, {root_b.id, root_a.id})
  local by_sorted = ids(rank.sorted(items, ranks))
  local by_key: {item.Item} = {}
  for _, i in ipairs(items) do
    by_key[#by_key + 1] = i
  end
  table.sort(by_key, function(x: item.Item, y: item.Item): boolean
      return rank.key(ranks, x.id) < rank.key(ranks, y.id)
    end)
  local by_key_ids = ids(by_key)
  assert(table.concat(by_sorted, ",") == table.concat(by_key_ids, ","),
    "the key's lexicographic order agrees with sorted: "
    .. table.concat(by_sorted, ",") .. " vs " .. table.concat(by_key_ids, ","))
end

local function test_describe_renders_position_root_and_unranked()
  local top = make({})
  local first = make({parent = top.id})
  local second = make({parent = top.id})
  local loose = make({parent = top.id})
  top.order = {first.id, second.id}
  local items: {item.Item} = {top, first, second, loose}
  local ranks = rank.positions(items, {top.id})
  assert(rank.describe(ranks, items, first.id) == "1 of 2 under "
    .. "«" .. top.id:sub(20, 23) .. "_" .. top.id:sub(24, 27) .. "»",
    rank.describe(ranks, items, first.id))
  assert(rank.describe(ranks, items, second.id):find("2 of 2 under", 1, true)
    ~= nil, rank.describe(ranks, items, second.id))
  assert(rank.describe(ranks, items, loose.id) == "unranked",
    rank.describe(ranks, items, loose.id))
  assert(rank.describe(ranks, items, top.id) == "root 1 of 1",
    rank.describe(ranks, items, top.id))
end
