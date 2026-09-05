--- `gitboard migrate`'s plan: everything computed IN MEMORY from a
--- layout-1 board's items, before anything is written — the board
--- (found or minted), every parent's `order` from `beats`
--- (`_work.gitmigrate_order`, split out to keep this file under the
--- line cap), every blocker's re-parent from `blocked_by`, and the
--- edges/held drop every touched item carries. `_work.gitmigrate` is
--- the only caller; it prints `Plan.lines` (dry run, or before writing)
--- and hands `Plan.write_items`/`Plan.drop_held` to `gitwrite.save_batch`.
---
--- Pure: no store, no git. `build` mutates the `item.Item` values it
--- was given in place (their `.parent`/`.order`/`.other_edges`) rather
--- than copying them — safe because `store.list_for_migrate` already
--- took its OWN snapshot (`Store.leased_item`) for `gitwrite`'s diff to
--- compare against before handing the live items back.
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local order = require("_work.gitmigrate_order")
local rank = require("_work.rank")

--- The exact decode problem `_work.itemtree.to_item` leaves when a
--- `held` blob was present — `item.Item` has no field for it, so this
--- string is the only way to learn an item had one.
local HELD_PROBLEM < const > = "held: marker this build does not interpret"

--- What `build` computed: every item to hand `gitwrite.save_batch`
--- (only the ones whose fields actually moved end up committed —
--- `gitwrite`'s own diff decides that), the ids whose `held` blob must
--- be force-deleted, and the listing — one line per change, dry run or
--- not, ending with the count line.
local record Plan
  write_items: {item.Item}
  drop_held: {string: boolean}
  lines: {string}
  board_id: string
end

--- An item's handle: its id's last 8 characters, this migration's own
--- rendering (plain, not guillemet-wrapped — `_work.rank`'s own
--- `handle_of` is not exported, and this verb is disposable after
--- cutover, so it does not need to match `show`'s render byte for
--- byte).
--- @param id string A full item id
--- @return string The handle
local function handle(id: string): string
  return id:sub(1, 8)
end

--- Whether `it` carries the one decode problem a `held` blob leaves.
--- @param it item.Item The item
--- @return boolean
local function was_held(it: item.Item): boolean
  for _, p in ipairs(it.decode_problems or {}) do
    if p == HELD_PROBLEM then
      return true
    end
  end
  return false
end

--- A fresh board item, built exactly as `_work.store`'s own (private)
--- `ensure_board` builds one — duplicated rather than called, since
--- `ensure_board` reads the board through `gitread.list`'s ordinary
--- format check, which a layout-1 board fails; `gitboard migrate` is
--- the one verb exempt from it, via `store.list_for_migrate` instead.
--- @return item.Item
local function new_board_item(): item.Item
  return {
    id = ksuid.new(), title = "board", parent = "", repo = "", base = "",
    key = "", order = {}, claim = "", builders = {}, speccers = {},
    reviewer = "", pr = 0, result = "", verdict = "", verdict_head = "",
    verdict_spec = "", resolution = "",
  }
end

--- The `blocked_by` targets `it` itself names, kind -> id -> reason on
--- `it.other_edges`; empty for an item with none.
--- @param it item.Item The item
--- @return {string: string} Blocker id -> reason (possibly "")
local function blocked_by_of(it: item.Item): {string: string}
  return (it.other_edges or {}).blocked_by or {}
end

--- Step 3: re-parent every blocker under the open waiter that ranks
--- highest after step 2 — `rank.sorted`'s first entry, since
--- `rank.less` itself is not exported — dropping every edge that
--- cannot apply: either side already done, no such item, or a losing
--- waiter when a blocker has more than one live one. Mutates `index`'s
--- items' `.parent` directly for every blocker that actually moves,
--- and `touched` (accumulator, mutated in place) for every id this
--- step wrote to.
--- @param items {item.Item} Every item, fields as step 1 and 2 left them
--- @param index {string: item.Item} The same items, by id
--- @param lines {string} Accumulator, appended to in place
--- @param touched {string: boolean} Accumulator, mutated in place
local function apply_blocked_by(items: {item.Item}, index: {string: item.Item},
    lines: {string}, touched: {string: boolean})
  local ranks = rank.positions(items)
  local waiters_of: {string: {string}} = {}
  for _, w in ipairs(items) do
    for bid, _reason in pairs(blocked_by_of(w)) do
      local b = index[bid]
      if b == nil then
        lines[#lines + 1] = ("dropped: %s blocked_by %s (no such item)"):format(
          handle(w.id), handle(bid))
      elseif not item.is_open(w) or not item.is_open(b) then
        lines[#lines + 1] = ("dropped: %s blocked_by %s (done item)"):format(
          handle(w.id), handle(bid))
      else
        waiters_of[bid] = waiters_of[bid] or {}
        waiters_of[bid][#waiters_of[bid] + 1] = w.id
      end
    end
  end
  local blocker_ids: {string} = {}
  for bid in pairs(waiters_of) do
    blocker_ids[#blocker_ids + 1] = bid
  end
  table.sort(blocker_ids)
  for _, bid in ipairs(blocker_ids) do
    local waiter_items: {item.Item} = {}
    for _, wid in ipairs(waiters_of[bid]) do
      waiter_items[#waiter_items + 1] = index[wid]
    end
    local winner = rank.sorted(waiter_items, ranks, "")[1].id
    for _, wid in ipairs(waiters_of[bid]) do
      if wid ~= winner then
        lines[#lines + 1] = ("dropped: %s blocked_by %s (parented under %s instead)")
        :format(handle(wid), handle(bid), handle(winner))
      end
    end
    local blocker = index[bid]
    if blocker.parent ~= winner then
      blocker.parent = winner
      touched[bid] = true
      lines[#lines + 1] = ("%s parent -> %s"):format(handle(bid), handle(winner))
    end
  end
end

--- Build the whole migration in memory. See `_work.gitmigrate`'s
--- header for the four steps this carries out, in order: the board,
--- per-parent `beats` orders, `blocked_by` re-parenting, and dropping
--- every `edges`/`held` remnant.
--- @param items {item.Item} Every item a layout-1 board holds
--- @return Plan
local function build(items: {item.Item}): Plan
  local index: {string: item.Item} = {}
  for _, it in ipairs(items) do
    index[it.id] = it
  end
  local lines: {string} = {}
  local touched: {string: boolean} = {}

  -- Step 1: the board.
  local board: item.Item = nil
  for _, it in ipairs(items) do
    if item.is_parentless(it) and it.title == "board" then
      board = it
    end
  end
  if board == nil then
    board = new_board_item()
    index[board.id] = board
    items[#items + 1] = board
    lines[#lines + 1] = ("board %s created"):format(handle(board.id))
  end
  touched[board.id] = true
  for _, it in ipairs(items) do
    if it.id ~= board.id and item.is_parentless(it) then
      it.parent = board.id
      touched[it.id] = true
    end
  end

  -- Step 2: per-parent order from `beats`, the board included (its
  -- children are the former roots, reparented just above).
  local children_of: {string: {string}} = {}
  for _, it in ipairs(items) do
    if it.id ~= board.id then
      children_of[it.parent] = children_of[it.parent] or {}
      local kids = children_of[it.parent]
      kids[#kids + 1] = it.id
    end
  end
  local parent_ids: {string} = {}
  for pid in pairs(children_of) do
    parent_ids[#parent_ids + 1] = pid
  end
  table.sort(parent_ids)
  for _, pid in ipairs(parent_ids) do
    local result = order.order_for(children_of[pid], index)
    for _, d in ipairs(result.dropped) do
      lines[#lines + 1] = ("dropped: %s beats %s (%s)"):format(
        handle(d.winner), handle(d.loser), d.reason)
    end
    if #result.cycle > 0 then
      local hs: {string} = {}
      for _, cid in ipairs(result.cycle) do
        hs[#hs + 1] = handle(cid)
      end
      lines[#lines + 1] = ("cycle under %s: %s"):format(handle(pid), table.concat(hs, " "))
    elseif #result.order > 0 then
      index[pid].order = result.order
      touched[pid] = true
      local hs: {string} = {}
      for _, cid in ipairs(result.order) do
        hs[#hs + 1] = handle(cid)
      end
      lines[#lines + 1] = ("%s order: %s"):format(handle(pid), table.concat(hs, " "))
    end
  end

  -- Step 3: prerequisites from `blocked_by`, arbitrated against the
  -- ranks step 1 and 2 just settled.
  apply_blocked_by(items, index, lines, touched)

  -- Step 4: drop every edges/* entry and every held blob. An item
  -- that carried either is touched regardless of what steps 1-3 did
  -- to it — `gitwrite.save_batch` still no-ops a genuinely unchanged
  -- item on its own diff, so over-including here costs nothing.
  local drop_held: {string: boolean} = {}
  for _, it in ipairs(items) do
    if next(it.other_edges or {}) ~= nil then
      touched[it.id] = true
    end
    if was_held(it) then
      drop_held[it.id] = true
      touched[it.id] = true
      lines[#lines + 1] = ("held dropped: %s"):format(handle(it.id))
    end
    it.other_edges = nil
  end

  local write_ids: {string} = {}
  for id in pairs(touched) do
    write_ids[#write_ids + 1] = id
  end
  table.sort(write_ids)
  local write_items: {item.Item} = {}
  for _, id in ipairs(write_ids) do
    write_items[#write_items + 1] = index[id]
  end
  lines[#lines + 1] = ("%d item(s) touched"):format(#write_items)

  return {write_items = write_items, drop_held = drop_held, lines = lines, board_id = board.id}
end

local record gitmigrate_plan
  type Plan = Plan
  HELD_PROBLEM: string
  build: function(items: {item.Item}): Plan
end

local M: gitmigrate_plan = {
  HELD_PROBLEM = HELD_PROBLEM,
  build = build,
}

return M
