#!/usr/bin/env cosmic
-- `_work.cachequery`: the `lanes` table round trip, and the
-- `similar_lines`/`cmd_find` wrappers that open the cache, query it,
-- and close it again.

local cachequery = require("_work.cachequery")
local fixture = require("_work.fixture")

local init_state_repo = fixture.init_state_repo
local file_item = fixture.file_item

local function test_lanes_read_write_round_trip()
  local s = init_state_repo("lanes-roundtrip")
  assert(next(cachequery.lanes_read(s.root)) == nil,
    "a board with no cache file has no observation yet")
  assert(cachequery.lanes_write(s.root, {["release.yml"] = "success"}))
  local facts = cachequery.lanes_read(s.root)
  assert(facts["release.yml"] == "success", tostring(facts["release.yml"]))
end

local function test_lanes_write_replaces_a_prior_conclusion()
  local s = init_state_repo("lanes-replace")
  assert(cachequery.lanes_write(s.root, {["release.yml"] = "failure"}))
  assert(cachequery.lanes_write(s.root, {["release.yml"] = "success"}))
  local facts = cachequery.lanes_read(s.root)
  assert(facts["release.yml"] == "success", tostring(facts["release.yml"]))
end

local function test_similar_lines_and_cmd_find_go_through_the_cache()
  local s = init_state_repo("cache-find")
  file_item(s, "add full text search over the board", "")
  local lines = cachequery.similar_lines(s.root, "add full text search over items")
  assert(#lines >= 1, "at least one similar line")
  assert(lines[1]:match("^similar: «%w[%w_-]*» .+$") ~= nil, lines[1])

  local seen: {string} = {}
  local old_print = _G.print
  _G.print = function(msg: any) seen[#seen + 1] = tostring(msg) end
  local rc = cachequery.cmd_find(s.root, "full text search")
  _G.print = old_print
  assert(rc == 0, "a hit is a success")
  assert(seen[#seen] == "gitboard-find: 1 hit(s)", seen[#seen])
end

local function test_cmd_find_reports_zero_hits_without_failing()
  local s = init_state_repo("cache-find-zero")
  file_item(s, "something else entirely", "")
  local seen: {string} = {}
  local old_print = _G.print
  _G.print = function(msg: any) seen[#seen + 1] = tostring(msg) end
  local rc = cachequery.cmd_find(s.root, "nonexistentword")
  _G.print = old_print
  assert(rc == 0, "zero hits is not a failure")
  assert(seen[#seen] == "gitboard-find: 0 hit(s)", seen[#seen])
end
