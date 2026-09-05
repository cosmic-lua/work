#!/usr/bin/env cosmic
-- The board format marker's pure decision: `_work.gitread.list`'s
-- integration (a hand-edited marker, a missing one on a real board)
-- lives in `_work/storeinit_test.tl`, beside `store.init_repo`'s own
-- tests, since that is what writes the marker in the first place.

local format = require("_work.format")

-- The current version, trailing newline and all (`blob`'s own shape),
-- is trusted as is.
local function test_current_version_is_trusted()
  assert(format.refusal(format.blob(), true) == nil)
  assert(format.refusal(format.blob(), false) == nil)
end

-- A stray trailing newline or blank line is trimmed before comparing
-- — the same tolerance every other blob this store reads back gets.
local function test_trailing_whitespace_is_trimmed()
  assert(format.refusal(format.CURRENT .. "\n\n", true) == nil)
  assert(format.refusal(format.CURRENT .. " \n", true) == nil)
end

-- A different version number is always refused, whatever it is —
-- named on both sides, so a reader can tell a too-old tool from a
-- too-new board without decoding the message.
local function test_a_different_version_refuses_and_names_both()
  local refusal = format.refusal("99", true)
  assert(refusal ~= nil)
  assert(refusal:find("99", 1, true) ~= nil, refusal)
  assert(refusal:find(format.CURRENT, 1, true) ~= nil, refusal)
  assert(format.refusal("99", false) ~= nil, "wrong on an empty board refuses too")
end

-- Layout `1` — the previous, beats/blocked_by/held-carrying layout —
-- is a refusal this tool knows the way past: it names `gitboard
-- migrate` rather than the generic "cannot safely read" wording.
local function test_version_1_names_the_migrate_verb()
  local refusal = format.refusal("1", true)
  assert(refusal ~= nil)
  assert(refusal:find("1", 1, true) ~= nil, refusal)
  assert(refusal:find(format.CURRENT, 1, true) ~= nil, refusal)
  assert(refusal:find("gitboard migrate", 1, true) ~= nil, refusal)
end

-- A missing marker refuses only once the board carries items — an OLD
-- layout, never a fresh one nothing has written to yet.
local function test_missing_marker_refuses_only_with_items()
  assert(format.refusal("", true) ~= nil, "missing + items is an old layout")
  assert(format.refusal("", false) == nil, "missing + nothing filed is fine")
end
