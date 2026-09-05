#!/usr/bin/env cosmic
-- `_work.cachequery`: the `lanes` table round trip, and the
-- `similar_lines`/`cmd_find` wrappers that open the cache, query it,
-- and close it again.

local cache = require("_work.cache")
local cachequery = require("_work.cachequery")
local check = require("cosmic.check")
local fixture = require("_work.fixture")
local tail = require("_work.tail")

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

-- `resolve_tail`: the four shapes a handle lookup against the cache
-- can take — no file yet, a miss, a single hit, and an ambiguous one
-- — each falling through ("" error) or refusing (a non-empty one) as
-- `_work.gitboard.resolve_id` expects.

local function test_resolve_tail_falls_through_when_the_cache_is_absent()
  local s = init_state_repo("cache-resolve-absent")
  local id, err = cachequery.resolve_tail(s.root, "«ZZZZ_ZZZZ»")
  assert(id == nil and err == "", "no cache file yet, so this falls through")
end

local function test_resolve_tail_falls_through_on_a_miss()
  local s = init_state_repo("cache-resolve-miss")
  file_item(s, "an item", "") -- warms the cache as a side effect of `new`
  local id, err = cachequery.resolve_tail(s.root, "ZZZZZZZZ")
  assert(id == nil and err == "", "no row carries this tail")
end

local function test_resolve_tail_resolves_a_single_hit()
  local s = init_state_repo("cache-resolve-hit")
  local id = file_item(s, "an item", "")
  local got, err = cachequery.resolve_tail(s.root, tail.handle(id))
  assert(got == id, tostring(got))
  assert(err == "", err)
end

local function test_resolve_tail_refuses_a_cache_row_ambiguity()
  local s = init_state_repo("cache-resolve-ambiguous")
  local c = check.must(cache.open(s.root))
  assert(c.db:exec("INSERT INTO items (id, title) VALUES (?, ?)",
      {"0000000000000000000AAABBBBB", "one"}))
  assert(c.db:exec("INSERT INTO items (id, title) VALUES (?, ?)",
      {"1111111111111111111AAABBBBB", "two"}))
  check.must(cache.close(c))
  local id, err = cachequery.resolve_tail(s.root, "AAABBBBB")
  assert(id == nil, "two rows share this tail")
  assert(err:find("ambiguous", 1, true), err)
end
