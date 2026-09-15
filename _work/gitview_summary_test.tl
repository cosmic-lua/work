#!/usr/bin/env cosmic
-- `show --summary` replaces each state's item rows with one line per
-- repository. These pin the WIRING in `status_report` — that every
-- state rolls up, and that the rows it replaces are actually gone.
-- The grouping and ordering themselves are `_work/viewsummary_test.tl`;
-- the rest of the status report is `_work/gitview_test.tl`.

local act = require("_work.action")
local check = require("cosmic.check")
local fixture = require("_work.fixture")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local view = require("_work.gitview")

local counter = 0

local function fresh_id(): string
  counter = counter + 1
  return check.must(ksuid.encode(1700000000 + counter, ("\0"):rep(16)))
end

local BOARD < const > = fresh_id()
local GOAL < const > = fresh_id()
local DOING < const > = fresh_id()
local TODO < const > = fresh_id()
local TRIAGE < const > = fresh_id()

--- A board carrying one item in each of the three rendered states, each
--- in a different repository — so a rollup that reached only todo shows
--- up as a missing line rather than a wrong count. TRIAGE is a child of
--- the board absent from its `order`, which is what leaves it untriaged.
local function board(): {item.Item}
  return {
    check.must(item.decode({id = GOAL, title = "a goal", parent = BOARD})),
    check.must(item.decode({id = DOING, title = "building", parent = GOAL,
          repo = "one/doing", claim = "session-a",
          handover_head = ("ab"):rep(20)})),
    check.must(item.decode({id = TODO, title = "waiting", parent = GOAL,
          repo = "two/todo"})),
    check.must(item.decode({id = TRIAGE, title = "untriaged", parent = BOARD,
          repo = "three/triage"})),
    check.must(item.decode({id = BOARD, title = "board", order = GOAL})),
  }
end

local function specs(): act.Specs
  local out: act.Specs = {}
  for _, i in ipairs(board()) do
    out[i.id] = {change = "Do exactly this.\n", non_goals = "Not that.\n"}
  end
  return out
end

local function report(summary: boolean): {string}
  local items = board()
  local c = fixture.make_index(items)
  local lines, verdict = view.status_report(c, items, specs(), nil, nil, nil,
    summary)
  assert(lines ~= nil, verdict)
  return lines
end

local function has(lines: {string}, needle: string): boolean
  for _, line in ipairs(lines) do
    if line:find(needle, 1, true) ~= nil then return true end
  end
  return false
end

local function test_every_state_rolls_up_not_just_todo()
  local lines = report(true)
  assert(has(lines, "one/doing"), "doing: " .. table.concat(lines, " | "))
  assert(has(lines, "two/todo"), "todo: " .. table.concat(lines, " | "))
  assert(has(lines, "three/triage"), "triage: " .. table.concat(lines, " | "))
end

local function test_no_rollup_line_appears_without_the_flag()
  for _, line in ipairs(report(false)) do
    assert(line:match("^  %S+/%S+%s+%d+$") == nil,
      "rollup leaked into the plain report: " .. line)
  end
end

local function test_summary_replaces_the_item_rows()
  for _, line in ipairs(report(true)) do
    assert(line:find("«", 1, true) == nil,
      "an item row survived --summary: " .. line)
  end
end

local function test_plain_report_still_renders_item_rows()
  -- The guard above is only meaningful if these rows exist to suppress.
  local found = false
  for _, line in ipairs(report(false)) do
    if line:find("«", 1, true) ~= nil then found = true end
  end
  assert(found, "the plain report renders item rows")
end

local function test_state_count_lines_survive_the_rollup()
  local lines = report(true)
  assert(has(lines, "doing"), "doing count: " .. table.concat(lines, " | "))
  assert(has(lines, "todo"), "todo count: " .. table.concat(lines, " | "))
  assert(has(lines, "triage"), "triage count: " .. table.concat(lines, " | "))
end
