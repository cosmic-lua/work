#!/usr/bin/env cosmic
-- `show ID` correlating `_work.overlap`'s exact Change-section path
-- collisions with `_work.find`'s fuzzy title/spec similarity: the same
-- other item firing BOTH signals renders one `likely duplicate: ...`
-- line instead of two a reader would otherwise have to notice
-- separately and connect by eye; a signal that fires alone still
-- renders exactly as it always did.

local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local gitspec = require("_work.gitspec")
local show = require("_work.gitshow")
local store = require("_work.store")
local tail = require("_work.tail")

local init_state_repo = fixture.init_state_repo
local file_item = fixture.file_item
local root_with_leaf = fixture.root_with_leaf

--- Set a custom spec sidecar meeting the ready bar, through the spec
--- verb, so `## Change` names a real path for `_work.overlap` to find.
--- @param s store.Store The store
--- @param id string The item whose spec is set
--- @param body string The spec markdown
local function write_spec(s: store.Store, id: string, body: string)
  local path = fs.join(fixture.tmpdir, "dup-spec-" .. id .. ".md")
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

-- Two items naming the SAME real path under `## Change`, with
-- near-identical titles and spec wording besides — both signals fire
-- for the same pair, so `show ID` prints one combined line rather than
-- an `overlaps:` line and a `similar:` line a reader has to notice are
-- about the same other item.
local function test_show_correlates_a_shared_path_with_similar_text()
  local s = init_state_repo("dup-both")
  local root = (root_with_leaf(s))
  local first = file_item(s, "add caching for the boards find index lookups", root)
  local second = file_item(s, "add caching for the boards find index lookup path", root)
  write_spec(s, first,
    "## Change\nWire caching into `_work/find.tl`'s ranked_rows lookup.\n")
  write_spec(s, second,
    "## Change\nWire caching into `_work/find.tl`'s ranked_rows lookup path.\n")

  local _, out_first = show_and_capture(s, first)
  assert(out_first:find("likely duplicate: " .. tail.handle(second), 1, true),
    "the combined line names the other item: " .. out_first)
  assert(out_first:match("likely duplicate: .- shares _work/find%.tl AND "
      .. "similar text %(ratio [%d%.]+%)"),
    "the combined line carries the shared path and a ratio: " .. out_first)
  assert(not out_first:find("overlaps: " .. tail.handle(second), 1, true),
    "no separate overlaps line once correlated: " .. out_first)
  assert(not out_first:find("similar: " .. tail.handle(second), 1, true),
    "no separate similar line once correlated: " .. out_first)

  -- Symmetric: `second`'s own report names `first` the same way.
  local _, out_second = show_and_capture(s, second)
  assert(out_second:find("likely duplicate: " .. tail.handle(first), 1, true),
    "the correlation is symmetric: " .. out_second)
end

-- Same near-identical wording as above, but the two items name
-- DIFFERENT real paths under `## Change` — only the similarity signal
-- fires, so today's standalone `similar:` line renders unchanged, with
-- no `overlaps:` or `likely duplicate:` line for this pair at all.
local function test_show_keeps_the_standalone_similar_line_with_no_shared_path()
  local s = init_state_repo("dup-similar-only")
  local root = (root_with_leaf(s))
  local first = file_item(s, "add caching for the boards find index lookups", root)
  local second = file_item(s, "add caching for the boards find index lookup path", root)
  write_spec(s, first,
    "## Change\nWire caching into `_work/find.tl`'s ranked_rows lookup.\n")
  write_spec(s, second,
    "## Change\nWire caching into `_work/cachequery.tl`'s ranked_rows lookup.\n")

  local _, out_first = show_and_capture(s, first)
  assert(out_first:find("similar: " .. tail.handle(second) .. " "
      .. "add caching for the boards find index lookup path", 1, true),
    "the standalone similar line still renders: " .. out_first)
  assert(not out_first:find("overlaps: " .. tail.handle(second), 1, true),
    "no shared path, no overlaps line: " .. out_first)
  assert(not out_first:find("likely duplicate:", 1, true),
    "one signal alone never renders as a duplicate: " .. out_first)
end
