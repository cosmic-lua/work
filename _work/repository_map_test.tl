#!/usr/bin/env cosmic
-- Repository identity resolution is explicit local configuration or an
-- explicit command override. It never discovers siblings or probes remotes.
local check = require("cosmic.check")
local child = require("cosmic.child")
local fs = require("cosmic.fs")
local repository_map = require("_work.repository_map")

local tmpdir = os.getenv("TEST_TMPDIR") or "/tmp"

local function git(root: string, args: {string})
  local argv: {string} = {"git"}
  for _, value in ipairs(args) do argv[#argv + 1] = value end
  local r = check.must(child.run(argv, {cwd = root}))
  assert(r.ok, "git " .. table.concat(args, " ") .. " failed: " .. r.stderr)
end

local function repo(name: string): string
  local root = fs.join(tmpdir, "repository-map-" .. name)
  assert(fs.remove_all(root))
  assert(fs.make_dirs(root))
  git(root, {"init", "-q"})
  return root
end

local function test_explicit_mapping_resolves_a_local_work_tree()
  local board = repo("board")
  local product = repo("product")
  git(board, {"config", "--local", "--add", "gitboard.repository",
      "acme/widgets=" .. product})
  local got, err = repository_map.resolve(board, "acme/widgets", "")
  assert(got == product, err)
  assert(repository_map.resolve(board, "acme/other", "") == nil,
    "an unmapped identity is never guessed")
end
test_explicit_mapping_resolves_a_local_work_tree()

local function test_override_wins_without_mutating_configuration()
  local board = repo("override-board")
  local configured = repo("configured")
  local override = repo("override")
  git(board, {"config", "--local", "--add", "gitboard.repository",
      "acme/widgets=" .. configured})
  local got, err = repository_map.resolve(board, "acme/widgets", override)
  assert(got == override, err)
end
test_override_wins_without_mutating_configuration()

local function test_selected_path_must_be_a_git_work_tree()
  local board = repo("bad-board")
  local plain = fs.join(tmpdir, "repository-map-plain")
  assert(fs.remove_all(plain))
  assert(fs.make_dirs(plain))
  local got, err = repository_map.resolve(board, "acme/widgets", plain)
  assert(got == nil and err:find("not a Git work tree", 1, true) ~= nil, err)
end
test_selected_path_must_be_a_git_work_tree()
