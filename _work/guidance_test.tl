#!/usr/bin/env cosmic
-- Guidance is what `next` says an action MEANS, and the property
-- that keeps it honest is completeness: the kinds are enumerated by
-- `_work.decision`, and every one of them has to have guidance, so a
-- kind added to the ordering cannot ship unexplained. The rest is
-- shape — the folding `next` relies on, and the terseness that keeps
-- a once-a-session read from becoming a wall of text.

local check = require("cosmic.check")
local decision = require("_work.decision")
local fixture = require("_work.fixture")
local guidance = require("_work.guidance")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local view = require("_work.gitview")

--- The most display lines one kind may spend. `next` is read every
--- session, so guidance that outgrows the action it explains is its
--- own failure.
local MAX_LINES < const > = 6
local HEAD < const > = ("a"):rep(40)

local function test_every_action_kind_has_guidance()
  for _, kind in ipairs(decision.KINDS) do
    local lines = guidance.lines(kind)
    assert(#lines > 0, "no guidance for action kind: " .. kind)
    for _, line in ipairs(lines) do
      assert(line:match("%S"), "blank guidance line for kind: " .. kind)
    end
  end
end

local function test_guidance_stays_terse()
  for _, kind in ipairs(decision.KINDS) do
    local lines = guidance.lines(kind)
    assert(#lines <= MAX_LINES,
      ("%s spends %d lines, over the %d-line budget"):format(kind, #lines,
        MAX_LINES))
  end
end

local function test_lines_fit_the_indented_width()
  for _, kind in ipairs(decision.KINDS) do
    for _, line in ipairs(guidance.lines(kind)) do
      assert(#line <= guidance.WIDTH,
        ("%s: %d columns over %d: %s"):format(kind, #line, guidance.WIDTH,
          line))
    end
  end
end

--- An unknown kind renders nothing at all rather than a blank block:
--- a caller appends what it is given, so "no guidance" has to be an
--- empty list.
local function test_an_unknown_kind_has_no_guidance()
  assert(#guidance.lines("something-else") == 0, "unknown kinds are silent")
  assert(#guidance.lines("") == 0, "and so is the empty kind")
end

--- Folding breaks at spaces and never mid-word, and a word past the
--- width takes a line to itself rather than being cut.
local function test_wrap_folds_at_spaces()
  local folded = guidance.wrap("one two three four", 11)
  assert(#folded == 2 and folded[1] == "one two" and folded[2] == "three four",
    "folded at the last space fitting the width: "
    .. table.concat(folded, "|"))
  local long = guidance.wrap("a supercalifragilistic word", 8)
  assert(long[2] == "supercalifragilistic",
    "an over-wide word keeps its own line: " .. table.concat(long, "|"))
  assert(#guidance.wrap("", 10) == 0, "nothing folds to nothing")
end

local counter = 0

--- A deterministic id; later calls sort later.
local function fresh_id(): string
  counter = counter + 1
  return check.must(ksuid.encode(1700000000 + counter, ("\0"):rep(16)))
end

--- The board `next` answers over: one root, one container under it,
--- one workable leaf awaiting a merge.
local function board_items(): {item.Item}
  local root = fresh_id()
  local container = fresh_id()
  return {
    check.must(item.decode({id = root, title = "an outcome"})),
    check.must(item.decode({id = container, title = "a piece of it",
          parent = root})),
    check.must(item.decode({id = fresh_id(), title = "a slice",
          parent = container, claim = "who", handover_head = HEAD,
          verdict = "accept"})),
  }
end

--- `next` prints the action line first and its guidance under it,
--- indented two spaces — so a session reads what to do and what it
--- means in one answer.
local function test_next_prints_guidance_under_the_action()
  local items = board_items()
  local c = fixture.make_index(items)
  local report, err = view.next_report(c, items, {})
  assert(err == "", err)
  local lines: {string} = {}
  for line in (report .. "\n"):gmatch("([^\n]*)\n") do
    lines[#lines + 1] = line
  end
  local kind = lines[1]:match("^(%S+)")
  assert(kind == "finish", "the action line still leads: " .. lines[1])
  local want = guidance.lines(kind)
  assert(#lines == #want + 1,
    ("%d line(s) under the action, %d of guidance"):format(#lines - 1, #want))
  for n, text in ipairs(want) do
    assert(lines[n + 1] == "  " .. text,
      "guidance line indented two spaces: " .. lines[n + 1])
  end
end

--- Guidance is invariant across item shapes: the current lifecycle always
--- names commit ids, while legacy provider fields are read compatibility only.
local function test_guidance_is_commit_only()
  local handed = check.must(item.decode({id = fresh_id(), title = "a change",
        claim = "who", builders = "who", handover_head = HEAD}))
  local lines = guidance.lines("review", handed)
  assert(#lines > 0 and #lines <= MAX_LINES, "within the budget: " .. #lines)
  for _, line in ipairs(lines) do
    assert(#line <= guidance.WIDTH, "within the width: " .. line)
  end
  local text = table.concat(lines, " ")
  assert(text:find("--head SHA", 1, true), "the verdict names its commit: " .. text)
  assert(not text:find("--pr", 1, true) and not text:find("CI proves", 1, true),
    "no provider fact becomes evidence: " .. text)

  local finish = table.concat(guidance.lines("finish", handed), " ")
  assert(finish:find("done ID --landed SHA", 1, true),
    "completion records the landed commit: " .. finish)
  assert(finish:find("take ID --head SHA", 1, true),
    "handover records the product commit: " .. finish)
  assert(not finish:find("--pr", 1, true), "finish cites no PR: " .. finish)
end
