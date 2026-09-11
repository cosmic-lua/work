#!/usr/bin/env cosmic
-- `default_base` tries the repo-mechanics resolver's own cached
-- `origin/HEAD` read before falling back to the repo-name heuristic; a
-- checkout with no reportable default proves that fallback chain is
-- exactly today's.
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local worktree = require("_work.gitworktree")

local git = fixture.git

local function checkout(name: string): string
  local root = fs.join(fixture.tmpdir, "default-base-" .. name)
  assert(fs.remove_all(root) and fs.make_dirs(root))
  git(root, {"init", "-q"})
  return root
end

local function test_resolver_default_wins_over_the_repo_name_heuristic()
  local root = checkout("resolver-wins")
  git(root, {"symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/develop"})
  -- Even a repo whose name would otherwise trip the cosmopolitan heuristic
  -- defers to a real reported default.
  assert(worktree.default_base("acme/cosmopolitan", "", root) == "develop")
  assert(worktree.default_base("acme/widgets", "", root) == "develop")
end

local function test_fallback_chain_matches_todays_behavior_without_a_resolver_default()
  local root = checkout("fallback")
  assert(worktree.default_base("acme/cosmopolitan", "", root) == "master")
  assert(worktree.default_base("acme/widgets", "", root) == "main")
end

-- The item's own `base` field is checked by the caller before
-- `default_base` is ever reached, but it must still win here too, over
-- a resolver default that would otherwise disagree with it.
local function test_explicit_base_field_wins_over_the_resolver_default()
  local root = checkout("explicit-base")
  git(root, {"symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/develop"})
  assert(worktree.default_base("acme/cosmopolitan", "release", root) == "release")
end
