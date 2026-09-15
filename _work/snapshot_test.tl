#!/usr/bin/env cosmic
local check = require("cosmic.check")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local git = require("_work.singlehead_git")
local literal = require("_work.singlehead_literal")
local objects = require("_work.stateplan_objects")
local projection = require("_work.stateplan_git")
local protocol = require("_work.snapshot_protocol")
local snapshot = require("_work.snapshot")
local tx = require("_work.statetransaction")

local AUTHOR: tx.Author = {name = "Session", email = "session@example.test",
  date = "1700000000 +0000"}

local function message(subject: string): string
  local encoded = check.must(literal.encode(AUTHOR)):gsub("\n$", "")
  return subject .. "\n\nGitboard-Author: " .. encoded .. "\n"
end

local function repo(name: string, count?: integer): string, string
  local root = fs.join(fixture.tmpdir, "snapshot-" .. name)
  assert(fs.remove_all(root)); assert(fs.make_dirs(root))
  check.must(git.run(root, {"init", "--quiet"}))
  local leaves: {objects.TreeElement} = {}
  for index = 1, count or 0 do
    leaves[#leaves + 1] = {path = ("untouched-%03d"):format(index),
      mode = "100644", otype = "blob", content = tostring(index)}
  end
  local tree = check.must(objects.make_tree(root, leaves))
  return root, check.must(objects.make_commit(root, tree, "base\n"))
end

local function destination(suffix?: string): snapshot.Destination
  return {repository = "example/board", branch = "state", remote = "origin",
    target_url = "https://github.com/example/board.git" .. (suffix or "")}
end

local function commit(root: string, parent: string, path: string,
    content: string, subject?: string): string
  local change: tx.Change = {path = path, mode = "100644", content = content,
    delete = false}
  local tree = check.must(projection.apply(root, parent, {change}))
  return check.must(git.text(root, {"commit-tree", tree, "-p", parent},
      message(subject or "update board"), {
        GIT_AUTHOR_NAME = AUTHOR.name, GIT_AUTHOR_EMAIL = AUTHOR.email,
        GIT_AUTHOR_DATE = AUTHOR.date, GIT_COMMITTER_NAME = "gitboard",
        GIT_COMMITTER_EMAIL = "gitboard@localhost", GIT_COMMITTER_DATE = AUTHOR.date}))
end

local function test_capture_rejects_a_malformed_logical_author_date()
  local root, base = repo("malformed-author-date")
  local tree = check.must(projection.apply(root, base,
      {{path = "item", mode = "100644", content = "changed", delete = false}}))
  local malformed = check.must(literal.encode({name = AUTHOR.name,
        email = AUTHOR.email, date = "nonsense"})):gsub("\n$", "")
  local candidate = check.must(git.text(root, {"commit-tree", tree, "-p", base},
      "bad date\n\nGitboard-Author: " .. malformed .. "\n", {
        GIT_AUTHOR_NAME = AUTHOR.name, GIT_AUTHOR_EMAIL = AUTHOR.email,
        GIT_AUTHOR_DATE = AUTHOR.date, GIT_COMMITTER_NAME = "gitboard",
        GIT_COMMITTER_EMAIL = "gitboard@localhost", GIT_COMMITTER_DATE = AUTHOR.date}))
  local identity, err = snapshot.commit_identity(root, candidate)
  assert(identity == nil and err:find("logical author", 1, true), err)
end
test_capture_rejects_a_malformed_logical_author_date()

local function test_identity_ignores_ambient_trailer_rules_and_checks_physical_author()
  local root, base = repo("hostile-trailer-config")
  local candidate = commit(root, base, "item", "new")
  local config = fs.join(root, "hostile.gitconfig")
  assert(fs.write(config, "[trailer]\n separators = %\n where = start\n"
      .. "[trailer \"Gitboard-Author\"]\n key = Poisoned-Author\n"
      .. "[core]\n commentChar = !\n"))
  local prior = env.get("GIT_CONFIG_GLOBAL")
  assert(env.set("GIT_CONFIG_GLOBAL", config))
  local ok, err = pcall(function()
      assert(check.must(snapshot.commit_identity(root, candidate)).author.name
        == AUTHOR.name)
      local identity = check.must(snapshot.commit_identity(root, candidate))
      local foreign = check.must(git.text(root,
          {"commit-tree", identity.tree, "-p", base}, identity.message, {
            GIT_AUTHOR_NAME = "Connector", GIT_AUTHOR_EMAIL = "connector@example.test",
            GIT_AUTHOR_DATE = AUTHOR.date, GIT_COMMITTER_NAME = "Connector",
            GIT_COMMITTER_EMAIL = "connector@example.test",
            GIT_COMMITTER_DATE = AUTHOR.date}))
      local plan, perr = snapshot.capture_validated(root, foreign,
        destination(), 0)
      assert(plan == nil and perr:find("physical author", 1, true), perr)
    end)
  if prior == nil then assert(env.unset("GIT_CONFIG_GLOBAL"))
  else assert(env.set("GIT_CONFIG_GLOBAL", prior)) end
  assert(ok, err)
end
test_identity_ignores_ambient_trailer_rules_and_checks_physical_author()

local function test_small_update_emits_delta_tree_and_bound_commit_calls()
  local root, base = repo("large", 120)
  local candidate = commit(root, base, "changed", "new")
  local plan = check.must(snapshot.capture_validated(root, candidate,
      destination(), 200))
  local calls = check.must(protocol.tree_calls(plan))
  assert(#calls == 1 and calls[1].tool == "github_create_tree")
  assert(not plan.complete_tree and #plan.entries == 1
    and plan.entries[1].path == "changed",
    "untouched leaves must not enter the connector payload")
  assert(calls[1].arguments.base_tree_sha == plan.base_tree)
  local commit_call = check.must(protocol.commit_call(plan, plan.tree))
  assert(commit_call.arguments.parent_sha == base
    and commit_call.arguments.message == plan.message)
  local wrong_commit, tree_err = protocol.commit_call(plan, plan.base_tree)
  assert(wrong_commit == nil and tree_err:find("different", 1, true), tree_err)
end
test_small_update_emits_delta_tree_and_bound_commit_calls()

local function test_delete_uses_complete_tree()
  local root, base = repo("delete", 3)
  local change: tx.Change = {path = "untouched-002", mode = "100644",
    content = "", delete = true}
  local tree = check.must(projection.apply(root, base, {change}))
  local candidate = check.must(git.text(root, {"commit-tree", tree, "-p", base},
      message("delete one"), {GIT_AUTHOR_NAME = AUTHOR.name,
        GIT_AUTHOR_EMAIL = AUTHOR.email, GIT_AUTHOR_DATE = AUTHOR.date,
        GIT_COMMITTER_NAME = "gitboard", GIT_COMMITTER_EMAIL = "gitboard@localhost",
        GIT_COMMITTER_DATE = AUTHOR.date}))
  local plan = check.must(snapshot.capture_validated(root, candidate,
      destination(), 200))
  local calls = check.must(protocol.tree_calls(plan))
  assert(plan.complete_tree and #plan.entries == 2
    and calls[1].arguments.base_tree_sha == nil)
end
test_delete_uses_complete_tree()
