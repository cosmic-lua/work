#!/usr/bin/env cosmic
-- `briefmeasure.measure`: the `## Measured at brief time` section a
-- `--tree` brief carries, over an item's declared `touches` — every
-- Teal path once, in declared order, with its line count and the
-- cap marker; `absent` for a path the checkout lacks; a non-Teal
-- path skipped, since the cap is a `.tl` rule.

local briefmeasure = require("_work.briefmeasure")
local check = require("cosmic.check")
local child = require("cosmic.child")
local fs = require("cosmic.fs")
-- Requiring the fixture module points this process at an empty global
-- git config (`GIT_CONFIG_GLOBAL`), which is what lets `git init` run
-- under the build fence, where the home directory's config is
-- unreadable; its own `git` helper returns nothing, and `rev-parse`
-- below needs stdout, so the runner stays local.
local _fixture = require("_work.fixture")

local tmpdir = os.getenv("TEST_TMPDIR") or "/tmp"

--- Write a file of exactly `n` lines, the way `wc -l` counts them.
--- @param path string Where to write it
--- @param n integer How many lines
local function write_n_lines(path: string, n: integer)
  local rows: {string} = {}
  for i = 1, n do
    rows[i] = "x"
  end
  assert(fs.make_dirs(fs.dirname(path)))
  assert(fs.write(path, table.concat(rows, "\n") .. "\n"))
end

--- A committed checkout carrying the given paths at the given counts.
--- @param name string A per-test suffix
--- @param files {string: integer} Path relative to the root, line count
--- @return string The checkout root
--- @return string Its short HEAD
local function seeded_tree(name: string, files: {string: integer}): string, string
  local root = fs.join(tmpdir, "measure-" .. name)
  assert(fs.remove_all(root) and fs.make_dirs(root))
  local function git(args: {string}): string
    local argv: {string} = {"git", "-c", "user.email=t@example.com",
      "-c", "user.name=t"}
    for _, a in ipairs(args) do argv[#argv + 1] = a end
    local r = check.must(child.run(argv, {cwd = root}))
    assert(r.ok, "git " .. table.concat(args, " ") .. ": " .. r.stderr)
    return (r.stdout:gsub("%s+$", ""))
  end
  git({"init", "-q", "-b", "main"})
  for path, n in pairs(files) do
    write_n_lines(fs.join(root, path), n)
  end
  git({"add", "-A"})
  git({"commit", "-q", "-m", "seed"})
  return root, git({"rev-parse", "--short", "HEAD"})
end

-- Every declared `.tl` path is one row in declared order, once each:
-- a count with the cap marker when it is within 40 lines of the cap,
-- `absent` when the checkout lacks it; a markdown path is no row.
local function test_measure_rows_follow_the_declared_list()
  local root, head = seeded_tree("rows", {
      ["src/a.tl"] = 10, ["src/tight.tl"] = 480, ["docs/x.md"] = 3,
    })
  local section = check.must(briefmeasure.measure(
      {"src/tight.tl", "docs/x.md", "src/a.tl", "src/gone.tl", "src/a.tl"}, root))
  local want = table.concat({
      ("## Measured at brief time (%s, %s)"):format(root, head),
      "src/tight.tl  480 lines (20 under the 500 cap)",
      "src/a.tl  10 lines",
      "src/gone.tl  absent",
    }, "\n")
  assert(section == want, "got:\n" .. section .. "\nwant:\n" .. want)
end

-- An empty declared list still carries the header, so a brief says
-- what it measured against even when there was nothing to measure.
local function test_measure_of_nothing_declared_is_the_header_alone()
  local root, head = seeded_tree("empty", {["src/a.tl"] = 1})
  local section = check.must(briefmeasure.measure({}, root))
  assert(section == ("## Measured at brief time (%s, %s)\n"):format(root, head),
    section)
end

-- A tree that is not there cannot name a HEAD, and the failure rides
-- the error slot rather than a half-written section.
local function test_measure_refuses_a_tree_with_no_head()
  local missing = fs.join(tmpdir, "measure-no-such-tree")
  assert(fs.remove_all(missing))
  local section, err = briefmeasure.measure({"src/a.tl"}, missing)
  assert(section == nil and err ~= "", "no HEAD is a failure: " .. tostring(err))
end
