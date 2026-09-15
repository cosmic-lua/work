#!/usr/bin/env cosmic
local check = require("cosmic.check")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local archive = require("_work.migrate6_archive")
local source = require("_work.migrate6_source")

local PREFIX < const > = "refs/remotes/origin/"

local function setup(name: string): string, string
  local root = fs.join(fixture.tmpdir, "archive-" .. name)
  assert(fs.remove_all(root)); assert(fs.make_dirs(root))
  fixture.git(root, {"init", "-q"})
  assert(fs.write(fs.join(root, "seed"), "x"))
  fixture.git(root, {"add", "seed"})
  fixture.git(root, {"commit", "-qm", "seed"})
  for _, ref in ipairs({"items/a", "items/b", "ended/x", "ended/y", "board/seq"}) do
    fixture.git(root, {"update-ref", PREFIX .. ref, "HEAD"})
  end
  local sources = check.must(source.snapshot(root, PREFIX))
  return root, check.must(archive.build(sources, PREFIX, nil))
end

local function count(lines: {string}, needle: string): integer
  local n = 0
  for _, line in ipairs(lines) do
    if line:find(needle, 1, true) ~= nil then n = n + 1 end
  end
  return n
end

local function test_wholly_absent_namespace_collapses_to_one_line()
  local root, witness = setup("unfetched")
  fixture.git(root, {"update-ref", "-d", PREFIX .. "items/a"})
  fixture.git(root, {"update-ref", "-d", PREFIX .. "items/b"})
  local out = archive.problems(root, witness, PREFIX)
  assert(count(out, "archive: refs/heads/items not fetched") == 1,
    "one line for the bucket: " .. table.concat(out, " | "))
  assert(count(out, "archive: removed refs/heads/items/") == 0,
    "no per-ref lines for it: " .. table.concat(out, " | "))
  local line = ""
  for _, l in ipairs(out) do if l:find("not fetched", 1, true) then line = l end end
  assert(line:find("2 of 2 witness refs absent", 1, true) ~= nil, "counts both: " .. line)
  assert(line:find("+refs/heads/items/*:refs/remotes/origin/items/*", 1, true) ~= nil,
    "names the refspec that repairs it: " .. line)
end

local function test_partly_present_namespace_stays_per_ref()
  local root, witness = setup("partial")
  fixture.git(root, {"update-ref", "-d", PREFIX .. "ended/x"})
  local out = archive.problems(root, witness, PREFIX)
  assert(count(out, "archive: removed refs/heads/ended/x") == 1,
    "the one absent ref is named: " .. table.concat(out, " | "))
  assert(count(out, "refs/heads/ended not fetched") == 0,
    "a partly-present bucket never collapses: " .. table.concat(out, " | "))
end

local function test_board_seq_keeps_its_per_ref_line()
  -- One ref cannot distinguish never-fetched from deleted, so it is never
  -- collapsed however absent it is.
  local root, witness = setup("seq")
  fixture.git(root, {"update-ref", "-d", PREFIX .. "board/seq"})
  local out = archive.problems(root, witness, PREFIX)
  assert(count(out, "archive: removed refs/heads/board/seq") == 1,
    "named per-ref: " .. table.concat(out, " | "))
  assert(count(out, "board/seq not fetched") == 0,
    "never collapsed: " .. table.concat(out, " | "))
end

local function test_moved_is_never_collapsed()
  local root, witness = setup("moved")
  assert(fs.write(fs.join(root, "seed"), "y"))
  fixture.git(root, {"add", "seed"})
  fixture.git(root, {"commit", "-qm", "second"})
  fixture.git(root, {"update-ref", PREFIX .. "items/a", "HEAD"})
  fixture.git(root, {"update-ref", "-d", PREFIX .. "items/b"})
  local out = archive.problems(root, witness, PREFIX)
  assert(count(out, "archive: moved refs/heads/items/a") == 1,
    "a moved ref is still named: " .. table.concat(out, " | "))
  assert(count(out, "refs/heads/items not fetched") == 0,
    "one present ref keeps the bucket per-ref: " .. table.concat(out, " | "))
end

local function test_intact_archive_reports_nothing()
  local root, witness = setup("intact")
  assert(#archive.problems(root, witness, PREFIX) == 0,
    "a complete archive is silent")
end

local function test_every_namespace_absent_is_three_lines_not_hundreds()
  local root, witness = setup("fresh")
  for _, ref in ipairs({"items/a", "items/b", "ended/x", "ended/y"}) do
    fixture.git(root, {"update-ref", "-d", PREFIX .. ref})
  end
  local out = archive.problems(root, witness, PREFIX)
  assert(#out == 2, "one line per wholly-absent bucket, got " .. tostring(#out)
    .. ": " .. table.concat(out, " | "))
end
