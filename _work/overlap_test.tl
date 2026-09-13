#!/usr/bin/env cosmic
-- Cross-item path collisions over declared `touches` lists: the pure
-- comparison (`collisions`, with its presence filter) and, against a
-- scratch state repository, what `show` prints when two open items
-- declare the same file — the fact an orchestrator would otherwise
-- only find by reading every candidate's list by hand and comparing
-- them.
--
-- `overlap.headroom_lines` — the spec bar's own path check, which needs
-- a git checkout per case rather than this file's plain scratch
-- directory — is covered by `_work/overlap_headroom_test.tl`.

local find = require("_work.find")
local fixture = require("_work.fixture")
local graph = require("_work.gitgraph")
local index = require("_work.index")
local overlap = require("_work.overlap")
local show = require("_work.gitshow")
local store = require("_work.store")
local tail = require("_work.tail")

local init_state_repo = fixture.init_state_repo
local file_item = fixture.file_item
local root_with_leaf = fixture.root_with_leaf

--- Three ids of a KSUID's shape, in creation order, so a rendered
--- handle and a sort over them are the real thing.
local FIRST < const > = "0000000000000000000AAAA0001"
local SECOND < const > = "0000000000000000000BBBB0002"
local THIRD < const > = "0000000000000000000CCCC0003"

--- Declare `paths` as an item's `touches`, through the set verb.
--- @param s store.Store The store
--- @param id string The item whose list is set
--- @param paths {string} The declared paths
local function declare(s: store.Store, id: string, paths: {string})
  assert(graph.cmd_set(s, id, nil, nil, nil, nil, nil, nil, paths) == 0,
    "set --touches should be accepted")
  fixture.caller_publish(s)
end

--- Run show.cmd_show and capture exactly what it prints via print() —
--- the swap-and-restore pattern the other verb tests use.
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

-- `collisions` compares PRESENT paths only: a declared path that names
-- nothing real is not a collision however both items spell it — a
-- stale entry from a rewritten plan, a file not yet created — and
-- `touches` stays advisory, so nothing here refuses anything. An
-- unrelated real path collides with nothing.
local function test_collisions_filter_to_present_paths_only()
  local touches: {string: {string}} = {
    [FIRST] = {"_work/brief.tl", "_work/no-such-file.tl"},
    [SECOND] = {"_work/no-such-file.tl", "_work/brief.tl"},
    [THIRD] = {"_work/gitshow.tl"},
  }
  local found = overlap.collisions(FIRST, touches)
  assert(#found == 1 and found[1].id == SECOND,
    "the sibling declaring the same present file collides")
  assert(#found[1].paths == 1 and found[1].paths[1] == "_work/brief.tl",
    "on the present path only: " .. table.concat(found[1].paths, ", "))
  assert(#overlap.collisions(THIRD, touches) == 0,
    "an unrelated real path collides with nothing")
  local ghost = overlap.collisions(FIRST, {
      [FIRST] = {"_work/no-such-file.tl"}, [SECOND] = {"_work/no-such-file.tl"},
    })
  assert(#ghost == 0, "a shared path that is gone is not a collision")
end

-- An item that declares nothing present collides with nothing, and
-- one with no list at all reads the same way — either answer comes
-- before any other item's list is inspected.
local function test_collisions_need_a_present_path_of_ones_own()
  assert(#overlap.collisions(FIRST, {[FIRST] = {}, [SECOND] = {"_work/brief.tl"}})
    == 0, "an empty declared list")
  assert(#overlap.collisions(FIRST, {[SECOND] = {"_work/brief.tl"}}) == 0,
    "an id with no list at all")
end

-- `lines` renders one `overlaps:` line per colliding item, in id order
-- (creation order) whatever order the map is walked in, naming the
-- shared paths in the checked item's own declared order; `inline`
-- joins them for `next`'s alternates, "" when nothing collides.
local function test_lines_and_inline_render_in_id_order()
  local touches: {string: {string}} = {
    [SECOND] = {"_work/brief.tl", "_work/gitshow.tl"},
    [THIRD] = {"_work/gitshow.tl"},
    [FIRST] = {"_work/brief.tl"},
  }
  local lines = overlap.lines(SECOND, touches)
  assert(#lines == 2, table.concat(lines, "; "))
  assert(lines[1] == "overlaps: " .. tail.handle(FIRST) .. " on _work/brief.tl",
    lines[1])
  assert(lines[2] == "overlaps: " .. tail.handle(THIRD) .. " on _work/gitshow.tl",
    lines[2])
  assert(overlap.inline(SECOND, touches) == lines[1] .. "; " .. lines[2])
  assert(overlap.inline(THIRD, {[THIRD] = {"_work/gitshow.tl"}}) == "",
    "nothing to say prints nothing")
end

-- Two open items declaring `_work/brief.tl` collide, and `show` says
-- so on each side; a third declaring an unrelated real path collides
-- with neither. The lists come off the item rows: no item's prose is
-- written or read here.
--
-- `find.similar` never returns "nothing close" on a fixture this
-- small — a handful of items share enough common words (bm25's IDF
-- over so few documents makes even a stopword look distinctive) that
-- `show ID` would correlate this test's OWN path-collision fixture
-- into `likely duplicate:`, testing `_work.gitshow`'s correlation
-- instead of `_work.overlap`'s standalone path signal this file means
-- to pin. Stubbed to report nothing close, the swap-and-restore
-- pattern `gitshow_test.tl` already uses to isolate one signal from a
-- confound it does not mean to exercise.
local function test_show_surfaces_a_declared_path_overlap()
  local real_similar = find.similar
  find.similar = function(_idx: index.Index, _title: string,
      _exclude_id?: string): find.Rows | nil, string
    return {}, ""
  end
  local ok, err = pcall(function(): boolean
      local s = init_state_repo("overlap")
      local root, first = root_with_leaf(s)
      local second = file_item(s, "another slice touching the same field", root)
      local unrelated = file_item(s, "an unrelated slice", root)
      declare(s, first, {"_work/brief.tl"})
      declare(s, second, {"_work/brief.tl"})
      declare(s, unrelated, {"_work/gitshow.tl"})

      local _, out_first = show_and_capture(s, first)
      assert(out_first:find("overlaps: " .. tail.handle(second)
          .. " on _work/brief.tl", 1, true),
        "the sibling declaring the same file is named: " .. out_first)

      local _, out_second = show_and_capture(s, second)
      assert(out_second:find("overlaps: " .. tail.handle(first)
          .. " on _work/brief.tl", 1, true),
        "the collision is symmetric: " .. out_second)

      local _, out_unrelated = show_and_capture(s, unrelated)
      assert(not out_unrelated:find("overlaps:", 1, true),
        "an unrelated path collides with nothing: " .. out_unrelated)
      return true
    end)
  find.similar = real_similar
  if not ok then
    error(err, 0)
  end
end
