#!/usr/bin/env cosmic
-- Cross-item path collisions: the pure text extraction (`paths_named`)
-- and, against a scratch state repository, what `show` prints when two
-- open items' `## Change` sections name the same file — the fact an
-- orchestrator would otherwise only find by reading every candidate's
-- spec by hand and comparing them. Plus `ready_when`, the other
-- Change-section signal this module carries.
--
-- `overlap.headroom_lines` — the spec bar's own path check, which needs
-- a git checkout per case rather than this file's plain scratch
-- directory — is covered by `_work/overlap_headroom_test.tl`.

local find = require("_work.find")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local gitspec = require("_work.gitspec")
local index = require("_work.index")
local overlap = require("_work.overlap")
local show = require("_work.gitshow")
local store = require("_work.store")
local tail = require("_work.tail")

local init_state_repo = fixture.init_state_repo
local file_item = fixture.file_item
local root_with_leaf = fixture.root_with_leaf

--- Set a custom spec sidecar meeting the ready bar, through the spec
--- verb — like `fixture.give_spec`, but with the caller's own body
--- rather than the fixed `READY_SPEC`, so a test can put a path in
--- `## Change` for `_work.overlap` to find.
--- @param s store.Store The store
--- @param id string The item whose spec is set
--- @param body string The spec markdown
local function write_spec(s: store.Store, id: string, body: string)
  local path = fs.join(fixture.tmpdir, "overlap-spec-" .. id .. ".md")
  assert(fs.write(path, body))
  assert(gitspec.cmd_spec(s, id, path) == 0, "spec should be accepted")
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

-- `paths_named` reads only backtick-quoted, path-looking tokens that
-- name a file actually present in the tree: a bare verb or flag caught
-- in backticks for other reasons is not a path, a comma-joined span
-- (not this repo's own backtick-per-path convention) carries a
-- character a path never does, and a path-shaped token that names
-- nothing real is not one either.
local function test_paths_named_filters_to_real_paths_only()
  local body = table.concat({
      "## Change", "Edit `_work/brief.tl` and `_work/gitverbs.tl`.",
      "Run `take` with `--why`, see `_work/no-such-file.tl` for a path",
      "that looks real but is not, and `_work/brief.tl, _work/gh.tl`",
      "for two real paths joined in one span, which is not how this",
      "repo writes them.",
    }, "\n")
  local paths = overlap.paths_named(body)
  assert(#paths == 2, table.concat(paths, ", "))
  assert(paths[1] == "_work/brief.tl" and paths[2] == "_work/gitverbs.tl",
    table.concat(paths, ", "))
end

-- Only the `## Change` section is read: a path elsewhere in the spec
-- (an `## Evidence` citation, say) names no collision.
local function test_paths_named_reads_only_the_change_section()
  local body = table.concat({
      "## Evidence", "Seen in `_work/brief.tl` already.",
      "## Change", "Touch `_work/gitverbs.tl`.",
    }, "\n")
  local paths = overlap.paths_named(body)
  assert(#paths == 1 and paths[1] == "_work/gitverbs.tl",
    table.concat(paths, ", "))
end

-- A thematic break ends the Change section the way it ends any other
-- (`_work.spec.sections`'s own rule): a path in a footer below one is
-- not read as part of it.
local function test_paths_named_stops_at_a_thematic_break()
  local body = table.concat({
      "## Change", "Touch `_work/gitverbs.tl`.", "",
      "---", "Also see `_work/brief.tl` below the break.",
    }, "\n")
  local paths = overlap.paths_named(body)
  assert(#paths == 1 and paths[1] == "_work/gitverbs.tl",
    table.concat(paths, ", "))
end

-- A `###` subheading inside `## Change` is part of Change, not a
-- section of its own (`_work.spec.sections`'s level rule), so a path
-- it names is a collision the board can see — the reading this module
-- otherwise lost on every spec that groups its Change by subheading.
local function test_paths_named_reads_a_change_subheading()
  local body = table.concat({
      "## Change", "Rework the scanner.", "",
      "### `_work/brief.tl`", "", "Also touch `_work/gitverbs.tl`.", "",
      "## Non-goals", "Nothing in `_work/gh.tl`.",
    }, "\n")
  local paths = overlap.paths_named(body)
  assert(#paths == 2, table.concat(paths, ", "))
  assert(paths[1] == "_work/brief.tl" and paths[2] == "_work/gitverbs.tl",
    table.concat(paths, ", "))
end

-- Two open items whose `## Change` sections both name `_work/brief.tl`
-- collide, and `show` says so on each side; a third naming an
-- unrelated real path collides with neither.
local OVERLAP_A < const > = table.concat({
    "## Change", "Edit `_work/brief.tl` for the new field.",
  }, "\n")
local OVERLAP_B < const > = table.concat({
    "## Change", "Also touch `_work/brief.tl` for the same field.",
  }, "\n")
local OVERLAP_UNRELATED < const > = table.concat({
    "## Change", "Touch `_work/gitshow.tl` only.",
  }, "\n")

-- `find.similar` never returns "nothing close" on a fixture this
-- small — a handful of items share enough common words (bm25's IDF
-- over so few documents makes even a stopword look distinctive) that
-- `show ID` would correlate this test's OWN path-collision fixture
-- into `likely duplicate:`, testing `_work.gitshow`'s correlation
-- instead of `_work.overlap`'s standalone path signal this file means
-- to pin. Stubbed to report nothing close, the swap-and-restore
-- pattern `gitshow_test.tl` already uses to isolate one signal from a
-- confound it does not mean to exercise.
local function test_show_surfaces_a_change_section_path_overlap()
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
      write_spec(s, first, OVERLAP_A)
      write_spec(s, second, OVERLAP_B)
      write_spec(s, unrelated, OVERLAP_UNRELATED)

      local _, out_first = show_and_capture(s, first)
      assert(out_first:find("overlaps: " .. tail.handle(second)
          .. " on _work/brief.tl", 1, true),
        "the sibling naming the same file is named: " .. out_first)

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

-- A `Ready when:` sentence whose command's trimmed stdout matches the
-- second span is ready: nil, nothing to refuse or skip on.
local function test_ready_when_nil_on_a_match()
  local body = table.concat({
      "## Change", "Ready when: `printf ready` prints `ready`.",
      "Then do the rest of the work.",
    }, "\n")
  assert(overlap.ready_when(body) == nil)
end

-- A mismatch names the command, what it actually printed, and what
-- ready would have looked like — the line `_work.gitready` appends and
-- `_work.gitview`'s live `next` prints ahead of its next candidate.
local function test_ready_when_not_ready_on_a_mismatch()
  local body = table.concat({
      "## Change", "Ready when: `printf ready` prints `done`.",
      "Then do the rest of the work.",
    }, "\n")
  local line = overlap.ready_when(body)
  assert(line == "not ready: `printf ready` printed `ready`;"
    .. " ready means `done`", tostring(line))
end

-- A sentence naming fewer than two backtick spans is prose ABOUT the
-- convention, not a command to run: `false` never spawns, so it never
-- gets the chance to mismatch the way it otherwise would.
local function test_ready_when_prose_only_spawns_nothing()
  local body = table.concat({
      "## Change", "Ready when: this depends on `false` somehow.",
      "Then do the rest of the work.",
    }, "\n")
  assert(overlap.ready_when(body) == nil)
end

-- No `Ready when:` sentence at all is the ordinary case: nothing to
-- check, nil without touching the process table.
local function test_ready_when_nil_with_no_such_sentence()
  local body = table.concat({"## Change", "Just do the thing."}, "\n")
  assert(overlap.ready_when(body) == nil)
end
