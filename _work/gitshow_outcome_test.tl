#!/usr/bin/env cosmic
-- `show ID`'s outcome block: the retrospective the item's OWN commits
-- carry — the body of the commit that set its resolution, or of its
-- latest handover while it is open — rendered under its own marker
-- beside the spec. The board writes no such prose today, so the block
-- is absent for every item it currently carries.

local check = require("cosmic.check")
local fixture = require("_work.fixture")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local publish = require("_work.publish")
local read = require("_work.read")
local show = require("_work.gitshow")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

local init_state_repo = fixture.init_state_repo

--- Run show.cmd_show and capture exactly what it prints via print().
--- @param s store.Store The store
--- @param id string The item to show
--- @return integer cmd_show's exit code
--- @return string Every print()'d line, newline-joined
local function show_and_capture(s: store.Store, id: string): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, result = pcall(show.cmd_show, s, id)
  _G.print = old_print
  if not ok then
    error(result, 0)
  end
  return result, table.concat(lines, "\n")
end

--- Record one more commit on `id`'s ref, message verbatim — subject,
--- then whatever body the verb put under it.
--- @param s store.Store The store
--- @param id string The item to move
--- @param op string The `Op:` trailer's verb
--- @param message string Subject, and body under a blank line
--- @param apply function(item.Item) The field change the commit records
local function record(s: store.Store, id: string, op: string, message: string,
    apply: function(item.Item))
  local it = check.must(store.load(s, id))
  apply(it)
  storewrite.set_op(s, op)
  assert(storewrite.save(s, it, message))
end

--- `show.show_report` over a minimal in-memory board, so the pure
--- render is asserted without a git read of any kind.
--- @param outcome string The outcome prose, "" for none
--- @param body string The spec sidecar, "" for none
--- @return {string} The lines
local function report_with(outcome: string, body: string): {string}
  local board = check.must(ksuid.encode(1700000000, ("\0"):rep(16)))
  local leaf = check.must(ksuid.encode(1700000001, ("\0"):rep(16)))
  local all: {item.Item} = {
    check.must(item.decode({id = board, title = "board"})),
    check.must(item.decode({id = leaf, title = "a slice", parent = board})),
  }
  local c = fixture.make_index(all)
  local it = all[2]
  local role = check.must(read.role(c, leaf))
  local rank_line = check.must(show.describe(c, it))
  local state = check.must(show.state_of(c, it))
  local events: {publish.Event} = {
    {sha = "abc1234", at = "2026-08-17T00:00:00Z", subject = "new " .. leaf:sub(1, 8)},
  }
  local lines = show.show_report(it, role, rank_line, state, body, events, {},
    {}, {}, {}, nil, nil, nil, outcome)
  return lines
end

--- The 1-based index of the first line equal to `wanted`, 0 for none.
--- @param lines {string} The rendered lines
--- @param wanted string The exact line
--- @return integer The index, 0 when absent
local function index_of(lines: {string}, wanted: string): integer
  for i, line in ipairs(lines) do
    if line == wanted then
      return i
    end
  end
  return 0
end

-- The outcome renders under its own marker, after the spec sidecar and
-- before the history block.
local function test_outcome_renders_under_its_own_marker_after_the_spec()
  local lines = report_with("measured 3x on the json path", "## Change\ndo it\n")
  local spec_at = index_of(lines, "--- spec ---")
  local outcome_at = index_of(lines, "--- outcome ---")
  assert(spec_at > 0 and outcome_at > spec_at,
    "the outcome follows the spec: " .. table.concat(lines, "\n"))
  assert(lines[outcome_at + 1] == "measured 3x on the json path",
    lines[outcome_at + 1])
  local history_at = 0
  for i, line in ipairs(lines) do
    if line:find("abc1234", 1, true) ~= nil then
      history_at = i
    end
  end
  assert(history_at > outcome_at, "the history stays last")
end

-- No outcome, no marker — and an item with no spec either still renders
-- one without the other.
local function test_no_outcome_prints_no_block()
  local lines = report_with("", "## Change\ndo it\n")
  assert(index_of(lines, "--- outcome ---") == 0,
    table.concat(lines, "\n"))
  local bare = report_with("what came of it", "")
  assert(index_of(bare, "--- spec ---") == 0, "no spec, no spec block")
  assert(index_of(bare, "--- outcome ---") > 0, "the outcome stands alone")
end

-- The board as it stands: a handover whose commit carries nothing but
-- gitboard's own trailers prints no outcome block at all.
local function test_show_prints_no_outcome_for_a_bodyless_handover()
  local s = init_state_repo("outcome-bodyless")
  local _root, leaf = fixture.root_with_leaf(s)
  fixture.give_spec(s, leaf)
  record(s, leaf, "take",
    ("take %s by session-a head:%s"):format(leaf:sub(1, 8), ("b"):rep(12)),
    function(it: item.Item)
      it.claim = "session-a"
      it.handover_head = ("b"):rep(40)
    end)
  local code, printed = show_and_capture(s, leaf)
  assert(code == 0, printed)
  assert(printed:find("--- outcome ---", 1, true) == nil,
    "nothing changes for the board as it stands: " .. printed)
end

-- A handover that recorded prose: `show ID` prints it while the item is
-- still open.
local function test_show_prints_an_open_items_handover_body()
  local s = init_state_repo("outcome-handover")
  local _root, leaf = fixture.root_with_leaf(s)
  fixture.give_spec(s, leaf)
  record(s, leaf, "take",
    ("take %s by session-a head:%s\n\nwhat the build found"):format(
      leaf:sub(1, 8), ("b"):rep(12)),
    function(it: item.Item)
      it.claim = "session-a"
      it.handover_head = ("b"):rep(40)
    end)
  local code, printed = show_and_capture(s, leaf)
  assert(code == 0, printed)
  assert(printed:find("--- outcome ---\nwhat the build found", 1, true) ~= nil,
    "the handover's own body: " .. printed)
  assert(printed:find("Op: take", 1, true) == nil,
    "the tool's trailer is not the outcome: " .. printed)
end

-- Once resolved, the commit that set the resolution is the outcome —
-- the handover's body no longer stands in for it.
local function test_show_prints_a_resolved_items_resolution_body()
  local s = init_state_repo("outcome-done")
  local _root, leaf = fixture.root_with_leaf(s)
  fixture.give_spec(s, leaf)
  record(s, leaf, "take",
    ("take %s by session-a head:%s\n\nwhat the build found"):format(
      leaf:sub(1, 8), ("b"):rep(12)),
    function(it: item.Item)
      it.claim = "session-a"
      it.handover_head = ("b"):rep(40)
    end)
  record(s, leaf, "done",
    ("done %s completed (from accepted)\n\nwhat came of it"):format(
      leaf:sub(1, 8)),
    function(it: item.Item)
      it.resolution = "completed"
    end)
  local code, printed = show_and_capture(s, leaf)
  assert(code == 0, printed)
  assert(printed:find("--- outcome ---\nwhat came of it", 1, true) ~= nil,
    "the resolution's own body: " .. printed)
  assert(printed:find("what the build found", 1, true) == nil,
    "not the handover's: " .. printed)
end
