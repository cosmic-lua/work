#!/usr/bin/env cosmic
local check = require("cosmic.check")
local child = require("cosmic.child")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local store = require("_work.store")
local reviewrange = require("_work.reviewrange")
local repository_map = require("_work.repository_map")
local brief = require("_work.brief")

local function git(root: string, args: {string}): string
  local argv = {"git", "-c", "user.name=test", "-c", "user.email=test@example.com"}
  for _, a in ipairs(args) do argv[#argv + 1] = a end
  local r = check.must(child.run(argv, {cwd = root}))
  assert(r.ok, r.stderr)
  return (r.stdout:gsub("%s+$", ""))
end

local function capture(s: store.Store, id: string): integer, string
  local old = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    lines[#lines + 1] = table.concat(parts, " ")
  end
  local ok, code = pcall(brief.cmd_brief, s, "review", id)
  _G.print = old
  if not ok then error(code, 0) end
  return code, table.concat(lines, "\n")
end

local function test_review_range_uses_target_merge_base()
  local s = fixture.init_state_repo("review-range")
  local _, id = fixture.root_with_leaf(s)
  fixture.give_spec(s, id)
  local root = fs.join(fixture.tmpdir, "review-range-product")
  assert(fs.remove_all(root) and fs.make_dirs(root))
  git(root, {"init", "-q", "-b", "main"})
  git(root, {"commit", "--allow-empty", "-qm", "base"})
  local base = git(root, {"rev-parse", "HEAD"})
  git(root, {"checkout", "-qb", "feature"})
  assert(fs.write(fs.join(root, "feature.tl"), "return true\n"))
  git(root, {"add", "."}); git(root, {"commit", "-qm", "feature"})
  local head = git(root, {"rev-parse", "HEAD"})
  local it = check.must(store.load(s, id))
  it.repo, it.base, it.handover_head = "acme/widgets", "", head
  assert(repository_map.resolve(s.root, it.repo, root))
  git(root, {"update-ref", "refs/remotes/origin/main", base})
  git(root, {"symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main"})
  assert(reviewrange.resolve(s.root, it) == base, "simple review resolves cached default")
  git(root, {"checkout", "-q", "main"})
  assert(fs.write(fs.join(root, "upstream"), "upstream only\n"))
  git(root, {"add", "."}); git(root, {"commit", "-qm", "upstream"})
  local target = git(root, {"rev-parse", "HEAD"})
  assert(reviewrange.resolve(s.root, it) == target, "independent target advance is valid")
  git(root, {"checkout", "-q", "feature"})
  git(root, {"merge", "-qm", "forward merge", "main"})
  it.handover_head = git(root, {"rev-parse", "HEAD"})
  assert(reviewrange.resolve(s.root, it) == target)
  fixture.claim_item(s, id, "reviewer", base)
  fixture.raw_seed_item(s, it, "record handover")
  local code, output = capture(s, id)
  local range = target .. "..." .. it.handover_head
  assert(code == 0 and output:find("Review `" .. range .. "`", 1, true) ~= nil,
    "forward merged review renders frozen three-dot range: " .. output)
  assert(git(root, {"diff", "--name-only", range}) == "feature.tl",
    "review range excludes upstream-only changes")
  assert(check.must(store.load(s, id)).claim_base == base, "claim base stays immutable")
  it.base = "feature"
  assert(reviewrange.resolve(s.root, it) == it.handover_head, "explicit base overrides default")
  it.base = "missing-base"
  local got, err = reviewrange.resolve(s.root, it)
  assert(got == nil and err:find(it.base, 1, true) and err:find(it.handover_head, 1, true), err)
  git(root, {"checkout", "--orphan", "unrelated"})
  git(root, {"commit", "--allow-empty", "-qm", "unrelated"})
  it.base = "unrelated"
  got, err = reviewrange.resolve(s.root, it)
  assert(got == nil and err:find("unrelated", 1, true) and err:find(it.handover_head, 1, true), err)
  local tree = git(root, {"rev-parse", target .. "^{tree}"})
  local left = git(root, {"commit-tree", tree, "-p", base, "-m", "left"})
  local right = git(root, {"commit-tree", tree, "-p", base, "-m", "right"})
  it.base = git(root, {"commit-tree", tree, "-p", left, "-p", right, "-m", "merge left"})
  it.handover_head = git(root, {"commit-tree", tree, "-p", right, "-p", left, "-m", "merge right"})
  got, err = reviewrange.resolve(s.root, it)
  assert(got == nil and err:find("ambiguous", 1, true) and err:find(it.base, 1, true)
    and err:find(it.handover_head, 1, true), "ambiguous merge bases refuse both sides: " .. err)
  it.base, it.handover_head = "main", ("f"):rep(40)
  got, err = reviewrange.resolve(s.root, it)
  assert(got == nil and err:find("main", 1, true) and err:find(it.handover_head, 1, true), err)
end

test_review_range_uses_target_merge_base()
