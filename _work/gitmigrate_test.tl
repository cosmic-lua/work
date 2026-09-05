#!/usr/bin/env cosmic
-- `gitboard migrate`: the one verb a layout-1 board is not refused
-- for. `_work.gitmigrate_fixture` hand-builds a layout-1 board (the
-- `edges/beats`/`edges/blocked_by`/`held` shape no writer makes any
-- more) covering every scenario the slice's spec names; this file
-- asserts the dry run's listing, the real run's result, the
-- already-migrated refusal, a lost race, and that ordinary verbs run
-- cleanly on what comes out the other side.

local check = require("cosmic.check")
local fixture = require("_work.gitmigrate_fixture")
local gitboard = require("_work.gitboard")
local item = require("_work.item")
local migrate = require("_work.gitmigrate")
local store = require("_work.store")
local storemigrate = require("_work.storemigrate")

local init_solo = fixture.init_solo
local init_shared = fixture.init_shared

--- An item's handle, matching `_work.gitmigrate_plan`'s own rendering.
--- @param id string
--- @return string
local function handle(id: string): string
  return id:sub(1, 8)
end

--- Run `migrate.cmd_migrate` and capture exactly what it prints via
--- `print()` — the same swap-and-restore pattern `_work.gitboard_test`
--- uses to pin a CLI's exact console output, without a real subprocess.
--- @param s store.Store
--- @param dry_run boolean
--- @return integer The exit code
--- @return string Every printed line, newline-joined
local function migrate_and_capture(s: store.Store, dry_run: boolean): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, result = pcall(migrate.cmd_migrate, s, dry_run)
  _G.print = old_print
  if not ok then
    error(result, 0)
  end
  return result, table.concat(lines, "\n")
end

-- The dry run prints every kind of plan line the slice names, and
-- writes nothing: the board stays unminted, the format marker stays
-- at 1, and a plain (non-bypassing) read still refuses it.
local function test_dry_run_lists_the_plan_and_writes_nothing()
  local s, sc = init_solo("dry-run")
  local before = check.must(storemigrate.list_for_migrate(s))
  local code, out = migrate_and_capture(s, true)
  assert(code == 0, out)

  local board_handle = out:match("board (%S+) created")
  assert(board_handle ~= nil, "a board-created line: " .. out)
  assert(out:find(("%s order: %s %s %s"):format(
        board_handle, handle(sc.r1), handle(sc.r2), handle(sc.r3)), 1, true) ~= nil,
    "the board's order line: " .. out)
  assert(out:find(("%s order: %s %s"):format(
        handle(sc.r5), handle(sc.c1), handle(sc.c2)), 1, true) ~= nil,
    "r5's order line: " .. out)
  assert(out:find(("dropped: %s beats %s (not a sibling)"):format(
        handle(sc.c1), handle(sc.r1)), 1, true) ~= nil,
    "the cross-subtree beats edge is dropped: " .. out)
  assert(out:find(("%s parent -> %s"):format(handle(sc.b1), handle(sc.w1)), 1, true) ~= nil,
    "the single-waiter reparent: " .. out)
  assert(out:find(("%s parent -> %s"):format(handle(sc.b2), handle(sc.c3)), 1, true) ~= nil,
    "the contested blocker goes to the higher-ranked waiter: " .. out)
  assert(out:find(("dropped: %s blocked_by %s (parented under %s instead)"):format(
        handle(sc.w3), handle(sc.b2), handle(sc.c3)), 1, true) ~= nil,
    "the losing waiter is listed: " .. out)
  assert(out:find(("dropped: %s blocked_by %s (done item)"):format(
        handle(sc.done_waiter), handle(sc.done_blocker)), 1, true) ~= nil,
    "a done item's edge is dropped: " .. out)
  assert(out:find(("held dropped: %s"):format(handle(sc.held_root)), 1, true) ~= nil,
    "the held root's marker is reported: " .. out)
  assert(out:find(("%s parent -> "):format(handle(sc.b3)), 1, true) == nil,
    "a blocker already the waiter's child gets no reparent line: " .. out)
  assert(out:find("item(s) touched", 1, true) ~= nil, "a final count line: " .. out)

  local after = check.must(storemigrate.list_for_migrate(s))
  assert(#after == #before, "nothing was written")
  for _, it in ipairs(after) do
    assert(it.title ~= "board", "no board item was minted")
  end
end

-- The real run: exactly one board item, every former root under it
-- (ranked or not), the contested blocker under its winning waiter,
-- the already-parented blocker untouched, no edges or held markers
-- anywhere, and format 2 — read back with the ORDINARY (non-bypassing)
-- `store.list`, which is the proof the board no longer needs the
-- exemption at all.
local function test_migrate_rewrites_the_board()
  local s, sc = init_solo("apply")
  local code, out = migrate_and_capture(s, false)
  assert(code == 0, out)
  assert(out:find("items rewritten, format 2", 1, true) ~= nil, out)

  local items = check.must(store.list(s))
  local index: {string: item.Item} = {}
  local board: item.Item = nil
  for _, it in ipairs(items) do
    index[it.id] = it
    if item.is_parentless(it) then
      assert(board == nil, "exactly one parentless item")
      board = it
    end
  end
  assert(board ~= nil, "a board item exists")
  assert(board.title == "board")
  assert(table.concat(board.order, " ") == table.concat({sc.r1, sc.r2, sc.r3}, " "),
    "the board ranks the beats chain, winners first")
  assert(index[sc.r1].parent == board.id and index[sc.r2].parent == board.id
    and index[sc.r3].parent == board.id, "the whole chain becomes children of the board")
  assert(index[sc.r4].parent == board.id, "the edge-less root still becomes a child")
  assert(index[sc.r5].parent == board.id)
  assert(table.concat(index[sc.r5].order, " ") == table.concat({sc.c1, sc.c2}, " "),
    "r5 ranks its own two children")
  assert(index[sc.c1].parent == sc.r5 and index[sc.c2].parent == sc.r5,
    "r5's own children are untouched by their re-parent")
  assert(index[sc.w1].parent == board.id)
  assert(index[sc.b1].parent == sc.w1, "the sole waiter gets its blocker")
  assert(index[sc.c3].parent == sc.r5, "c3 (w2) stays where it was")
  assert(index[sc.b2].parent == sc.c3, "the contested blocker goes to the higher-ranked waiter")
  assert(index[sc.r7].parent == board.id)
  assert(index[sc.w3].parent == sc.r7, "the losing waiter keeps its own parent")
  assert(index[sc.b3].parent == sc.w4, "already-parented blocker is untouched")
  assert(index[sc.done_waiter].parent == board.id, "a done root still becomes a child")
  assert(index[sc.done_blocker].parent == board.id, "its dropped edge's target is untouched")
  assert(index[sc.held_root].parent == board.id)
  assert(not item.is_flagged(index[sc.held_root]), "the held marker is gone, not just unread")

  for _, it in ipairs(items) do
    assert(it.other_edges == nil or next(it.other_edges) == nil,
      it.id:sub(1, 8) .. " carries no edges")
    assert(not item.is_flagged(it), it.id:sub(1, 8) .. ": " .. table.concat(
        it.decode_problems or {}, "; "))
  end

  -- A second migrate is refused outright.
  local code2, out2 = migrate_and_capture(s, false)
  assert(code2 ~= 0, "a second migrate is refused")
  assert(out2:find("already on layout 2", 1, true) ~= nil, out2)

  -- Ordinary verbs run on the result.
  assert(gitboard.main("show", "--dir", s.root) == 0)
  assert(gitboard.main("next", "--dir", s.root) == 0)
end

-- Two checkouts race: the loser's push is rejected as a lost race
-- (the format ref, minted with a different board id on each side,
-- cannot both land), and it re-syncs onto the winner's already-migrated
-- board, so its own retry is refused as already-migrated rather than
-- replayed.
local function test_a_losing_migrate_refuses_lost_race_and_the_retry_sees_the_winner()
  local a, b = init_shared("race")
  assert(migrate.cmd_migrate(a, false) == 0, "a's migrate lands")
  assert(migrate.cmd_migrate(b, false) ~= 0, "b's stale migrate is refused")
  local a_items = check.must(store.list(a))
  local b_items = check.must(store.list(b))
  assert(#a_items == #b_items,
    "b's checkout matches the remote after the refusal's re-sync")
  local code2, out2 = migrate_and_capture(b, false)
  assert(code2 ~= 0)
  assert(out2:find("already on layout 2", 1, true) ~= nil,
    "b's retry sees a's already-migrated board: " .. out2)
end
