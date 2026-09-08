#!/usr/bin/env cosmic
-- `worktree --review`: the handed-over-checkout twin of `worktree`, tested
-- separately from `gitworktree_test.tl`'s builder scenarios. It uses the exact
-- locally present `handover_head` and the same whole-item claim as the builder.

local check = require("cosmic.check")
local child = require("cosmic.child")
local claim = require("_work.claim")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local graph = require("_work.gitgraph")
local gitclaim = require("_work.gitclaim")
local store = require("_work.store")
local storewrite = require("_work.storewrite")
local worktree = require("_work.gitworktree")

local git = fixture.git
local tmpdir = fixture.tmpdir

-- The session every fixture item's review is claimed under, except
-- the case exercising the claim refusal itself.
local SESSION < const > = "review-fixture-9doI"

--- A bare "origin" seeded with a `main` branch, plus a second branch
--- (`pr-src`) one commit ahead that overwrites `README` with distinct
--- content — the fixture's stand-in for a GitHub pull request:
--- `refs/pull/<pr>/head` in the bare repo is pointed at `pr-src`'s
--- tip, exactly the ref GitHub itself publishes for an open PR, so a
--- happy-path test can tell the review checkout landed the PR's head
--- rather than `main`.
--- @param name string A unique fixture name
--- @param pr integer The PR number to publish `refs/pull/<pr>/head` under
--- @return string The `--root` checkout's absolute path
--- @return string The fixture's own base directory
local function make_pr_checkout(name: string, pr: integer): string, string
  local base = fs.join(tmpdir, "wt-review-" .. name)
  assert(fs.remove_all(base))
  assert(fs.make_dirs(base))
  local bare = fs.join(base, "origin.git")
  git(base, {"init", "-q", "--bare", bare})
  local seed = fs.join(base, "seed")
  git(base, {"clone", "-q", bare, seed})
  git(seed, {"checkout", "-q", "-b", "main"})
  assert(fs.write(fs.join(seed, "README"), "main content\n"))
  git(seed, {"add", "-A"})
  git(seed, {"commit", "-q", "-m", "seed"})
  git(seed, {"push", "-q", "origin", "main"})
  git(seed, {"checkout", "-q", "-b", "pr-src"})
  assert(fs.write(fs.join(seed, "README"), "pr content\n"))
  git(seed, {"add", "-A"})
  git(seed, {"commit", "-q", "-m", "pr change"})
  git(seed, {"push", "-q", "origin", "pr-src"})
  local sha = assert(child.run({"git", "rev-parse", "refs/heads/pr-src"},
      {cwd = bare}))
  local sha_line = (sha.stdout or ""):gsub("%s+$", "")
  git(bare, {"update-ref", ("refs/pull/%d/head"):format(pr), sha_line})
  git(bare, {"branch", "-q", "-D", "pr-src"})
  local checkout = fs.join(base, "checkout")
  git(base, {"clone", "-q", bare, checkout})
  git(checkout, {"checkout", "-q", "main"})
  git(checkout, {"fetch", "-q", "origin",
      ("refs/pull/%d/head:refs/pull/%d/head"):format(pr, pr)})
  return checkout, base
end

--- A review checkout whose `bin/cosmic` stub actually runs (bootstrap
--- left enabled) and echoes compile noise before its build PASS
--- summary. The loud stub is committed on `pr-src` itself, since a
--- review checkout lands exactly the caller-prepared PR head's content,
--- never `main`'s. The build also touches a sentinel at the worktree
--- root so a test can tell it ran even when output never reaches print.
--- @param name string A unique fixture name
--- @param pr integer The PR number to publish `refs/pull/<pr>/head` under
--- @return string The `--root` checkout's absolute path
local function make_loud_pr_checkout(name: string, pr: integer): string
  local base = fs.join(tmpdir, "wt-review-" .. name)
  assert(fs.remove_all(base))
  assert(fs.make_dirs(base))
  local bare = fs.join(base, "origin.git")
  git(base, {"init", "-q", "--bare", bare})
  local seed = fs.join(base, "seed")
  git(base, {"clone", "-q", bare, seed})
  git(seed, {"checkout", "-q", "-b", "main"})
  assert(fs.write(fs.join(seed, "README"), "main content\n"))
  git(seed, {"add", "-A"})
  git(seed, {"commit", "-q", "-m", "seed"})
  git(seed, {"push", "-q", "origin", "main"})
  git(seed, {"checkout", "-q", "-b", "pr-src"})
  assert(fs.write(fs.join(seed, "README"), "pr content\n"))
  assert(fs.make_dirs(fs.join(seed, "bin")))
  local script = table.concat({
      "#!/bin/sh",
      "here=\"$(cd \"$(dirname \"$0\")\" && pwd)\"",
      "touch \"$here/../build_ran\"",
      "echo 'compile o/bin/cosmic a.tl o/a.lua --include-dir .'",
      "echo 'compile-batch o/bin/cosmic o/.groups/x.compiled o/x --srcs a.tl'",
      "echo 'build: PASS (3 files, 1 binary)'",
    }, "\n") .. "\n"
  assert(fs.write(fs.join(seed, "bin/cosmic"), script))
  assert(fs.set_mode(fs.join(seed, "bin/cosmic"), tonumber("755", 8)))
  git(seed, {"add", "-A"})
  git(seed, {"commit", "-q", "-m", "pr change + loud stub"})
  git(seed, {"push", "-q", "origin", "pr-src"})
  local sha = assert(child.run({"git", "rev-parse", "refs/heads/pr-src"},
      {cwd = bare}))
  local sha_line = (sha.stdout or ""):gsub("%s+$", "")
  git(bare, {"update-ref", ("refs/pull/%d/head"):format(pr), sha_line})
  git(bare, {"branch", "-q", "-D", "pr-src"})
  local checkout = fs.join(base, "checkout")
  git(base, {"clone", "-q", bare, checkout})
  git(checkout, {"checkout", "-q", "main"})
  git(checkout, {"fetch", "-q", "origin",
      ("refs/pull/%d/head:refs/pull/%d/head"):format(pr, pr)})
  return checkout
end

--- A workable item carrying a repository, handed-over commit, and active
--- whole-item claim under `SESSION`.
--- @param name string A unique fixture name
--- @param pr integer The item's `pr` field
--- @return store.Store, string The board and the item's id
local function item_with_pr(name: string, pr: integer,
    checkout: string): store.Store, string
  local s = fixture.init_state_repo(name)
  local _root, leaf = fixture.root_with_leaf(s)
  assert(graph.cmd_set(s, leaf, nil, "acme/widgets", "main") == 0)
  local it = check.must(store.load(s, leaf))
  it.claim = SESSION
  it.pr = pr
  local base = assert(child.run({"git", "rev-parse", "refs/heads/main"},
      {cwd = checkout}))
  local handed = assert(child.run({"git", "rev-parse",
        ("refs/pull/%d/head"):format(pr)}, {cwd = checkout}))
  it.claim_base = (base.stdout:gsub("%s+$", ""))
  it.handover_head = (handed.stdout:gsub("%s+$", ""))
  assert(storewrite.save(s, it, "fixture: review claim + pr for worktree"))
  return s, leaf
end

local function branch_of(s: store.Store, id: string): string
  local it = check.must(store.load(s, id))
  local st = check.must(gitclaim.read_state(s.root, s.leased_sha[id],
      it.claim or "", it.claim_base or ""))
  return claim.branch(id, st.root)
end

-- The happy path: a fresh stable claim branch and matching nested worktree
-- appear at the exact handed-over commit, not at `main`.
local function test_worktree_review_creates_checkout_at_review_path()
  local checkout = make_pr_checkout("happy", 42)
  local s, leaf = item_with_pr("wtr-happy", 42, checkout)
  local branch = branch_of(s, leaf)
  local expect = fs.join(fs.dirname(checkout), "wt", branch)
  assert(worktree.cmd_worktree(s, leaf, SESSION, checkout, {}, true, false) == 0)
  assert(fs.is_dir(expect), "the review worktree exists at its stable claim path")
  local content = assert(fs.read(fs.join(expect, "README")))
  assert(content == "pr content\n",
    "checked out the PR's head, not main: " .. content)
  local r = assert(child.run({"git", "rev-parse", "--abbrev-ref", "HEAD"},
      {cwd = expect}))
  assert((r.stdout:gsub("%s+$", "")) == branch,
    "branched under the stable claim identity: " .. r.stdout)
end

-- Never reuses a review checkout: a second call over the same item
-- refuses outright, same as a builder's.
local function test_worktree_review_refuses_a_repeat()
  local checkout = make_pr_checkout("repeat", 7)
  local s, leaf = item_with_pr("wtr-repeat", 7, checkout)
  assert(worktree.cmd_worktree(s, leaf, SESSION, checkout, {}, true, false) == 0)
  assert(worktree.cmd_worktree(s, leaf, SESSION, checkout, {}, true, false) ~= 0,
    "a second --review call over the same item refuses")
end

-- No handed-over commit recorded: refused before any product Git operation.
local function test_worktree_review_refuses_with_no_pr()
  local checkout = make_pr_checkout("nopr", 1)
  local s = fixture.init_state_repo("wtr-nopr")
  local _root, leaf = fixture.root_with_leaf(s)
  assert(graph.cmd_set(s, leaf, nil, "acme/widgets", "main") == 0)
  local it = check.must(store.load(s, leaf))
  it.reviewer = SESSION
  assert(storewrite.save(s, it, "fixture: review claim, no pr"))
  local id8 = leaf:sub(1, 8)
  local expect = fs.join(fs.dirname(checkout), "wt", "review-" .. id8)
  assert(worktree.cmd_worktree(s, leaf, SESSION, checkout, {}, true, false) ~= 0,
    "an item with no PR recorded is refused")
  assert(not fs.is_dir(expect), "no worktree directory was created")
end

-- An item without a valid Git-backed whole-item claim refuses outright.
local function test_worktree_review_refuses_when_unclaimed()
  local checkout = make_pr_checkout("unclaimed", 3)
  local s = fixture.init_state_repo("wtr-unclaimed")
  local _root, leaf = fixture.root_with_leaf(s)
  assert(graph.cmd_set(s, leaf, nil, "acme/widgets", "main") == 0)
  local it = check.must(store.load(s, leaf))
  it.claim = SESSION
  it.pr = 3
  assert(storewrite.save(s, it, "fixture: build claim only, no review claim"))
  local id8 = leaf:sub(1, 8)
  local expect = fs.join(fs.dirname(checkout), "wt", "review-" .. id8)
  local code = worktree.cmd_worktree(s, leaf, SESSION, checkout, {}, true, false)
  assert(code ~= 0,
    "a legacy holder field alone is not a valid Git-backed claim")
  assert(not fs.is_dir(expect), "no worktree directory was created")
end

-- A whole-item claim held by a different session refuses too, naming
-- whose claim it actually is.
local function test_worktree_review_refuses_a_different_sessions_claim()
  local checkout = make_pr_checkout("foreign", 5)
  local s, leaf = item_with_pr("wtr-foreign", 5, checkout)
  local expect = fs.join(fs.dirname(checkout), "wt", branch_of(s, leaf))
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local code = worktree.cmd_worktree(s, leaf, "review-a-different-session",
    checkout, {}, true, false)
  _G.print = old_print
  local out = table.concat(lines, "\n")
  assert(code ~= 0, "a different session's review claim is refused")
  assert(out:find(SESSION, 1, true) ~= nil,
    "the refusal names whose claim it is: " .. out)
  assert(not fs.is_dir(expect), "no worktree directory was created")
end

-- --verbose applies the same way to a review checkout's bootstrap as
-- to a builder's (`gitworktree_test.tl`'s own
-- `test_worktree_verbose_bootstrap_streams_verbatim`): the stub still
-- actually runs (its own sentinels prove it), but its output goes
-- straight to the real stdout (inherited) rather than through the
-- caller's own print — none of it, compile noise or PASS lines alike,
-- shows up there.
local function test_worktree_review_verbose_bootstrap_streams_verbatim()
  local checkout = make_loud_pr_checkout("verbose", 99)
  local s, leaf = item_with_pr("wtr-verbose", 99, checkout)
  local wt = fs.join(fs.dirname(checkout), "wt", branch_of(s, leaf))
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, err = pcall(function(): boolean
      assert(worktree.cmd_worktree(s, leaf, SESSION, checkout, {}, true, true) == 0)
      return true
    end)
  _G.print = old_print
  if not ok then
    error(err, 0)
  end
  assert(fs.is_file(fs.join(wt, "build_ran")), "the build step actually ran")
  local out = table.concat(lines, "\n")
  assert(out:find("compile", 1, true) == nil
    and out:find("PASS (3 files", 1, true) == nil,
    "verbose streams straight to the real stdout, none of it through print: "
    .. out)
end
