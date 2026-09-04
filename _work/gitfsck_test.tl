#!/usr/bin/env cosmic
-- `fsck`: `structural_problems` unit-tested directly over hand-built
-- items (no git at all, for the checks that never survive a real
-- write's own gates — a root with a repo, say), and `cmd_fsck` over
-- two real boards: one healthy, one carrying a beats edge written
-- straight through `store.save` (`gitready`'s own checks are a take
-- gate, not a write gate, so this never touches them).

local check = require("cosmic.check")
local fixture = require("_work.fixture")
local fsck = require("_work.gitfsck")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local store = require("_work.store")

local init_state_repo = fixture.init_state_repo
local root_with_leaf = fixture.root_with_leaf

--- Run `fsck.cmd_fsck` and capture what it printed, the way
--- `gitboard_test.tl`'s own helper pins a CLI verb's console output.
--- @param s store.Store The store
--- @return integer Exit code
--- @return string Every print()'d line, newline-joined
local function fsck_and_capture(s: store.Store): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local code = fsck.cmd_fsck(s)
  _G.print = old_print
  return code, table.concat(lines, "\n")
end

-- A healthy board — one placed root, one workable leaf, nothing
-- flagged — has no problems and says so, item count included.
local function test_a_healthy_board_has_no_problems()
  local s = init_state_repo("fsck-healthy")
  local _root, _leaf = root_with_leaf(s)
  local code, printed = fsck_and_capture(s)
  assert(code == 0, printed)
  assert(printed == "gitboard-fsck: ok (3 items)",
    "root, peer, leaf: 3 items, nothing else printed — got: " .. printed)
end

-- A beats edge naming an id that is not an item — written straight
-- through `store.save`, never through a verb, since `_work.gitready`'s
-- own dangling-blocker check is a TAKE gate, never a write gate — is
-- exactly what `fsck` exists to catch: nothing else on the board ever
-- asks this question.
local function test_a_dangling_beats_edge_is_caught()
  local s = init_state_repo("fsck-dangling-beats")
  local root, _leaf = root_with_leaf(s)
  local ghost = check.must(ksuid.encode(1690000001, ("\2"):rep(16)))
  local it = check.must(store.load(s, root))
  it.beats = {ghost}
  assert(store.save(s, it, "hand-edited beats"))
  local code, printed = fsck_and_capture(s)
  assert(code ~= 0, "a dangling beats edge is a problem: " .. printed)
  assert(printed:find("beats " .. ghost, 1, true) ~= nil, printed)
  assert(printed:find("which is not an item", 1, true) ~= nil, printed)
  assert(printed:find("gitboard-fsck: 1 problem(s)", 1, true) ~= nil, printed)
end

--- A minimal valid item.
--- @param over {string: any} Fields to override
--- @return item.Item The item
local function make_item(over?: {string: any}): item.Item
  local t: {string: any} = {
    id = check.must(ksuid.encode(1690000002, ("\3"):rep(16))), title = "an item",
  }
  for k, v in pairs(over or {}) do
    t[k] = v
  end
  return check.must(item.decode(t))
end

-- Two open items sharing a lane: `_work.lanes.mint`'s own idempotency
-- key is only checked at mint time, so a hand-edited second claimant
-- is exactly the shape `fsck` exists to catch.
local function test_two_open_items_in_one_lane_is_a_problem()
  local a = make_item({lane = "release.yml"})
  local b = make_item({id = check.must(ksuid.encode(1690000003, ("\4"):rep(16))),
      lane = "release.yml"})
  local problems = fsck.structural_problems({a, b})
  local found = false
  for _, p in ipairs(problems) do
    if p:find("release.yml", 1, true) ~= nil then
      found = true
    end
  end
  assert(found, table.concat(problems, "; "))
end

-- A root carrying a `repo` never survives `item.problems`'s own gate
-- at write time — `structural_problems` re-asks it anyway, over a
-- hand-built record no write path produced, the same defense in depth
-- every other check here is.
local function test_a_root_with_a_repo_is_a_problem()
  local root = make_item({repo = "cosmic-lua/cosmic"})
  local problems = fsck.structural_problems({root})
  local found = false
  for _, p in ipairs(problems) do
    if p:find("a root takes no repo", 1, true) ~= nil then
      found = true
    end
  end
  assert(found, table.concat(problems, "; "))
end

-- `decode_problems` a tolerant decode already flagged rides straight
-- through as an `fsck` problem too — the read that shows everything
-- else about the board shows this.
local function test_a_flagged_item_is_a_problem()
  local flagged = make_item()
  flagged.decode_problems = {"a made-up content problem"}
  local problems = fsck.structural_problems({flagged})
  assert(#problems == 1 and problems[1]:find("a made-up content problem", 1, true) ~= nil,
    table.concat(problems, "; "))
end
