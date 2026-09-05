-- `_work.gitshow.describe`'s render of an item's rank path: "N of M
-- under «HANDLE»" for a ranked child, "outcome N of M" for a direct
-- child of the board, "the board" for the board itself, and
-- "unranked" for an item its own parent has no position for.

local check = require("cosmic.check")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local rank = require("_work.rank")
local show = require("_work.gitshow")

local counter = 0

--- A fresh deterministic id; later calls sort later, so creation order
--- is age order exactly as live ksuids behave.
local function fresh_id(): string
  counter = counter + 1
  return check.must(ksuid.encode(1700000000 + counter, ("\0"):rep(16)))
end

--- One valid item, `order` space-joined the way `decode` expects.
local function make(over: {string: any}): item.Item
  local t: {string: any} = {id = fresh_id(), title = "item"}
  for k, v in pairs(over or {}) do
    t[k] = v
  end
  return check.must(item.decode(t))
end

local function test_describe_renders_the_board_outcomes_and_unranked()
  local board = make({})
  local top = make({parent = board.id})
  local first = make({parent = top.id})
  local second = make({parent = top.id})
  local loose = make({parent = top.id})
  top.order = {first.id, second.id}
  board.order = {top.id}
  local items: {item.Item} = {board, top, first, second, loose}
  local ranks = rank.positions(items)
  assert(show.describe(ranks, items, first.id) == "1 of 2 under "
    .. "«" .. top.id:sub(20, 23) .. "_" .. top.id:sub(24, 27) .. "»",
    show.describe(ranks, items, first.id))
  assert(show.describe(ranks, items, second.id):find("2 of 2 under", 1, true)
    ~= nil, show.describe(ranks, items, second.id))
  assert(show.describe(ranks, items, loose.id) == "unranked",
    show.describe(ranks, items, loose.id))
  assert(show.describe(ranks, items, top.id) == "outcome 1 of 1",
    show.describe(ranks, items, top.id))
  assert(show.describe(ranks, items, board.id) == "the board",
    show.describe(ranks, items, board.id))
end
