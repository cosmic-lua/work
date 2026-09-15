#!/usr/bin/env cosmic
local item = require("_work.item")
local viewsummary = require("_work.viewsummary")

local function make(id: string, repo: string): item.Item
  return {id = id, title = "t", repo = repo,
    access = {}, touches = {}, depends_on = {}, builders = {}, speccers = {},
    order = {}}
end

local function test_groups_by_repo_descending_by_count()
  local items = {make("a", "one/x"), make("b", "two/y"), make("c", "one/x"),
    make("d", "two/y"), make("e", "one/x")}
  local groups = viewsummary.group(items, nil)
  assert(#groups == 2, "two distinct repos, got " .. tostring(#groups))
  assert(groups[1].repo == "one/x", "largest first, got " .. groups[1].repo)
  assert(groups[1].count == 3, "got " .. tostring(groups[1].count))
  assert(groups[2].repo == "two/y", "got " .. groups[2].repo)
  assert(groups[2].count == 2, "got " .. tostring(groups[2].count))
end

local function test_equal_counts_break_ties_by_name()
  local groups = viewsummary.group({make("a", "zz/z"), make("b", "aa/a")}, nil)
  assert(groups[1].repo == "aa/a", "ties sort by name, got " .. groups[1].repo)
  assert(groups[2].repo == "zz/z", "got " .. groups[2].repo)
end

local function test_unset_repo_sorts_last_whatever_its_count()
  -- The placeholder outnumbers every real repo here; it still sorts
  -- last, because it names a gap rather than a place work lands.
  local items = {make("a", ""), make("b", ""), make("c", ""), make("d", "one/x")}
  local groups = viewsummary.group(items, nil)
  assert(#groups == 2, "got " .. tostring(#groups))
  assert(groups[1].repo == "one/x", "real repo first, got " .. groups[1].repo)
  assert(groups[2].repo == viewsummary.NO_REPO,
    "placeholder last, got " .. groups[2].repo)
  assert(groups[2].count == 3, "got " .. tostring(groups[2].count))
end

local function test_pullable_counted_per_repo_when_given()
  local items = {make("a", "one/x"), make("b", "one/x"), make("c", "two/y")}
  local groups = viewsummary.group(items, {a = true, c = true})
  assert(groups[1].repo == "one/x", "got " .. groups[1].repo)
  assert(groups[1].pullable == 1, "got " .. tostring(groups[1].pullable))
  assert(groups[2].pullable == 1, "got " .. tostring(groups[2].pullable))
end

local function test_lines_carry_pullable_only_when_asked()
  local items = {make("a", "one/x")}
  local with = viewsummary.lines(items, {a = true})
  assert(with[1]:find("(1 pullable)", 1, true) ~= nil, "got " .. with[1])
  local without = viewsummary.lines(items, nil)
  assert(without[1]:find("pullable", 1, true) == nil, "got " .. without[1])
  assert(without[1]:find("one/x", 1, true) ~= nil, "names the repo: " .. without[1])
end

local function test_emit_appends_in_place()
  local out = {"first"}
  viewsummary.emit(out, {make("a", "one/x")}, nil)
  assert(#out == 2, "appended one line, got " .. tostring(#out))
  assert(out[1] == "first", "existing lines kept, got " .. out[1])
end

local function test_no_items_renders_nothing()
  assert(#viewsummary.lines({}, nil) == 0, "an empty state has no rollup")
end
