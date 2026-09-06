#!/usr/bin/env cosmic
-- Cross-item path collisions: the pure text extraction (`paths_named`)
-- and, against a scratch state repository, what `show` prints when two
-- open items' `## Change` sections name the same file — the fact an
-- orchestrator would otherwise only find by reading every candidate's
-- spec by hand and comparing them.

local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local gitspec = require("_work.gitspec")
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

--- Write a file of exactly `n` lines, the way `wc -l` counts them: `n`
--- newline characters, matching `overlap.line_count`'s own measure.
--- @param path string Where to write it
--- @param n integer How many lines
local function write_n_lines(path: string, n: integer)
  local rows: {string} = {}
  for i = 1, n do
    rows[i] = "x"
  end
  assert(fs.write(path, table.concat(rows, "\n") .. "\n"))
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

local function test_show_surfaces_a_change_section_path_overlap()
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
end

-- `headroom_lines` warns right at the margin: a file with exactly
-- `WARN_MARGIN` lines of headroom left (480/500) is already tight
-- enough to flag.
local function test_headroom_lines_warns_at_the_margin()
  local path = fs.join(fixture.tmpdir, "overlap-headroom-480.tl")
  write_n_lines(path, 480)
  local body = ("## Change\nTouch `%s`.\n"):format(path)
  local lines = overlap.headroom_lines(body)
  assert(#lines == 1, table.concat(lines, "; "))
  assert(lines[1]:find("`" .. path .. "` is 480/500 lines, 20 left", 1, true),
    lines[1])
end

-- One line of MORE headroom (479/500, 21 lines left) is outside the
-- margin and stays quiet — the boundary the margin actually draws.
local function test_headroom_lines_silent_with_room_to_spare()
  local path = fs.join(fixture.tmpdir, "overlap-headroom-479.tl")
  write_n_lines(path, 479)
  local body = ("## Change\nTouch `%s`.\n"):format(path)
  local lines = overlap.headroom_lines(body)
  assert(#lines == 0, table.concat(lines, "; "))
end

-- A Change section naming a path this process's own tree does not
-- have (a product repo's file, read from the board's own checkout)
-- warns about nothing: the tree it can honestly measure is the only
-- one it claims to.
local function test_headroom_lines_silent_for_an_unreachable_path()
  local body = "## Change\nTouch `some/other/repo/big_file.tl`.\n"
  local lines = overlap.headroom_lines(body)
  assert(#lines == 0, table.concat(lines, "; "))
end

-- `fs.is_present` passes a directory (`paths_named` keeps it), but
-- `fs.read` cannot read one as text — the gap `line_count`'s own nil
-- check exists for, distinct from a path missing outright.
local function test_headroom_lines_silent_for_an_unreadable_present_path()
  local path = fs.join(fixture.tmpdir, "overlap-headroom.tl")
  assert(fs.make_dirs(path))
  local body = ("## Change\nTouch `%s`.\n"):format(path)
  local lines = overlap.headroom_lines(body)
  assert(#lines == 0, table.concat(lines, "; "))
end

-- `show` prints the same `tight:` line for a real item whose spec
-- names a file already within the margin — the warning a refiner or
-- builder sees before a pull, not after hitting the lint cap live.
local function test_show_surfaces_a_tight_change_section_path()
  local s = init_state_repo("headroom")
  local _root, first = root_with_leaf(s)
  local path = fs.join(fixture.tmpdir, "overlap-headroom-show.tl")
  write_n_lines(path, 480)
  local body = ("## Change\nTouch `%s`.\n"):format(path)
  write_spec(s, first, body)

  local _, out = show_and_capture(s, first)
  assert(out:find("tight: `" .. path .. "` is 480/500", 1, true),
    "the tight file is named: " .. out)
end
