#!/usr/bin/env cosmic
-- `_work.find`: FTS5 query escaping (punctuation is always a literal,
-- never syntax), `build`/`query` against a real store's items and
-- specs, `similar`'s closeness filter, and the `find` verb's printed
-- lines and verdict.

local check = require("cosmic.check")
local find = require("_work.find")
local fixture = require("_work.fixture")
local index = require("_work.index")
local store = require("_work.store")

local init_state_repo = fixture.init_state_repo
local file_item = fixture.file_item

--- An index over `s`'s current board, with the search table built.
--- @param s store.Store The store
--- @return index.Index The built index
local function built_index(s: store.Store): index.Index
  local all = check.must(store.list(s))
  local ids: {string} = {}
  for _, it in ipairs(all) do
    ids[#ids + 1] = it.id
  end
  local idx = check.must(index.open(all, store.read_specs(s, ids)))
  assert(find.build(idx))
  return idx
end

local function test_query_finds_a_title_word()
  local s = init_state_repo("query-title")
  file_item(s, "fix the sqlite index loader", "")
  file_item(s, "an unrelated capture about zebras", "")
  local idx = built_index(s)
  local hits = check.must(find.query(idx, "sqlite", 10))
  assert(#hits == 1, ("expected one hit: %d"):format(#hits))
  assert(hits[1].title:find("sqlite", 1, true), hits[1].title)
  assert(hits[1].state == "todo", hits[1].state)
  assert(hits[1].snippet ~= "", "a snippet is always returned")
  check.must(index.close(idx))
end

local function test_query_matches_across_title_and_spec()
  local s = init_state_repo("query-spec")
  local path = fixture.tmpdir .. "/find-spec.md"
  local body = fixture.READY_SPEC .. "\nthe word xenoblade appears only here.\n"
  assert(require("cosmic.fs").write(path, body))
  local id = file_item(s, "an item with a distinctive spec", "")
  assert(require("_work.gitspec").cmd_spec(s, id, path) == 0)
  local idx = built_index(s)
  local hits = check.must(find.query(idx, "xenoblade", 10))
  assert(#hits == 1 and hits[1].id == id, "the spec word finds the item")
  check.must(index.close(idx))
end

local function test_query_returns_no_hits_for_an_empty_query()
  local s = init_state_repo("query-empty")
  file_item(s, "something", "")
  local idx = built_index(s)
  local hits = check.must(find.query(idx, "   ", 10))
  assert(#hits == 0, "whitespace tokenizes to nothing")
  check.must(index.close(idx))
end

-- Punctuation FTS5 would otherwise read as operator syntax (AND, -,
-- *, parentheses, a bare quote) must never fail the query — it is
-- always a literal substring of the typed text.
local function test_query_treats_punctuation_as_a_literal()
  local s = init_state_repo("query-punct")
  file_item(s, [[fix the "loader" (again) - not* a bug]], "")
  local idx = built_index(s)
  local ok, err = idx.db:exec("SELECT 1") -- sanity: connection is alive
  assert(ok, err)
  local hits, qerr = find.query(idx, [[(again) - not* "loader"]], 10)
  assert(hits ~= nil, tostring(qerr))
  check.must(index.close(idx))
end

local function test_similar_finds_a_close_title_and_ignores_the_rest()
  local s = init_state_repo("similar")
  file_item(s, "add full text search over the board", "")
  file_item(s, "an unrelated capture about zebras", "")
  local idx = built_index(s)
  local hits = check.must(find.similar(idx, "add full text search over items"))
  assert(#hits >= 1, "the close title is found")
  local found_zebra = false
  for _, h in ipairs(hits) do
    if h.title:find("zebra", 1, true) then
      found_zebra = true
    end
  end
  assert(not found_zebra, "an unrelated title is not close")
  check.must(index.close(idx))
end

local function test_similar_returns_nothing_for_a_wholly_new_title()
  local s = init_state_repo("similar-none")
  file_item(s, "zzz zzz zzz zzz", "")
  local idx = built_index(s)
  local hits = check.must(find.similar(idx, "qqq qqq qqq qqq"))
  assert(#hits == 0, "no overlap, nothing close")
  check.must(index.close(idx))
end

local function test_similar_lines_formats_a_handle_and_title()
  local s = init_state_repo("similar-lines")
  file_item(s, "add full text search over the board", "")
  local lines = find.similar_lines(s, "add full text search over items")
  assert(#lines >= 1, "at least one similar line")
  assert(lines[1]:match("^similar: «%w[%w_-]*» .+$") ~= nil, lines[1])
end

local function test_cmd_find_prints_hits_and_a_verdict()
  local s = init_state_repo("cmd-find")
  file_item(s, "fix the sqlite index loader", "")
  local seen: {string} = {}
  local old_print = _G.print
  _G.print = function(msg: any) seen[#seen + 1] = tostring(msg) end
  local rc = find.cmd_find(s, "sqlite")
  _G.print = old_print
  assert(rc == 0, "a hit is a success")
  local last = seen[#seen]
  assert(last == "gitboard-find: 1 hit(s)", last)
  assert(seen[1]:find("sqlite", 1, true), seen[1])
end

local function test_cmd_find_reports_zero_hits_without_failing()
  local s = init_state_repo("cmd-find-zero")
  file_item(s, "something else entirely", "")
  local seen: {string} = {}
  local old_print = _G.print
  _G.print = function(msg: any) seen[#seen + 1] = tostring(msg) end
  local rc = find.cmd_find(s, "nonexistentword")
  _G.print = old_print
  assert(rc == 0, "zero hits is not a failure")
  assert(seen[#seen] == "gitboard-find: 0 hit(s)", seen[#seen])
end
