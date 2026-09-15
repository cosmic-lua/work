#!/usr/bin/env cosmic
--- A merged side branch is not a publication on the canonical first parent.
local check = require("cosmic.check")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local git = require("_work.singlehead_git")
local objects = require("_work.stateplan_objects")
local projection = require("_work.stateplan_git")
local recovery = require("_work.snapshot_recovery")
local snapshot = require("_work.snapshot")

local function commit(root: string, tree: string, parents: {string},
    message: string, at: string): string
  local args = {"commit-tree", tree}
  for _, parent in ipairs(parents) do
    args[#args + 1] = "-p"
    args[#args + 1] = parent
  end
  return check.must(git.text(root, args, message, {
        GIT_AUTHOR_NAME = "Session", GIT_AUTHOR_EMAIL = "session@example.test",
        GIT_AUTHOR_DATE = at, GIT_COMMITTER_NAME = "provider",
        GIT_COMMITTER_EMAIL = "provider@example.test", GIT_COMMITTER_DATE = at}))
end

local function merged_candidate(name: string): string, snapshot.Plan, string, string
  local root = fs.join(fixture.tmpdir, name)
  assert(fs.remove_all(root) and fs.make_dirs(root))
  check.must(git.run(root, {"init", "--quiet"}))
  local empty = check.must(objects.make_tree(root, {}))
  local base = commit(root, empty, {}, "base\n", "1700000000 +0000")
  local tree = check.must(projection.apply(root, base,
      {{path = "item", mode = "100644", content = "candidate", delete = false}}))
  local author: snapshot.Author = {name = "Session",
    email = "session@example.test", date = "1700000010 +0000"}
  local message = check.must(snapshot.message("candidate", author))
  local local_commit = commit(root, tree, {base}, message, author.date)
  local plan = check.must(snapshot.capture_validated(root, local_commit,
      {repository = "example/board", branch = "state", remote = "origin",
        target_url = "https://github.com/example/board.git"}, 0))
  local side = commit(root, tree, {base}, message, "1700000011 +0000")
  local main = commit(root, empty, {base}, "unrelated canonical change\n",
    "1700000001 +0000")
  -- Give the side candidate a newer date than the first parent. A normal
  -- all-parent walk visits it first, so removing either first-parent option
  -- would falsely accept the exact candidate instead of proving conflict.
  local merged = commit(root, tree, {main, side}, "merge side branch\n",
    "1700000020 +0000")
  return root, plan, side, merged
end

local function test_saved_candidate_on_merge_second_parent_never_confirms()
  local root, plan, side, merged = merged_candidate("snapshot-second-parent-saved")
  local state: recovery.Recovery = {format = recovery.FORMAT, phase = "updating",
    local_commit = plan.local_commit, repository = plan.destination.repository,
    branch = plan.destination.branch, remote = plan.destination.remote,
    target_url = plan.destination.target_url, remote_sha = side}
  local outcome = check.must(recovery.reconcile(root, merged, plan, state))
  assert(outcome.status == "conflict", "second-parent candidate must not confirm: " .. outcome.status)
end

local function test_cleaned_candidate_on_merge_second_parent_never_confirms()
  local root, plan, _side, merged = merged_candidate("snapshot-second-parent-cleaned")
  local outcome = check.must(recovery.discover(root, merged, plan))
  assert(outcome.status == "conflict", "second-parent discovery must not confirm: " .. outcome.status)
end
