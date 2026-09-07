#!/usr/bin/env cosmic
-- `worktree --review`: the review-checkout twin of `worktree`, tested
-- separately from `gitworktree_test.tl`'s builder scenarios — it
-- fetches the PR's CURRENT head onto its own branch rather than
-- branching off base, and its claim comes from ID's `reviewer` field,
-- not its build `claim`.

local check = require("cosmic.check")
local child = require("cosmic.child")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local graph = require("_work.gitgraph")
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
  return checkout, base
end

--- A workable item carrying a `repo` and PR, review-claimed under
--- `SESSION` — `worktree --review` refuses one with no PR, but
--- refuses even sooner over an unclaimed review, so every fixture
--- past that gate needs a review claim too.
--- @param name string A unique fixture name
--- @param pr integer The item's `pr` field
--- @return store.Store, string The board and the item's id
local function item_with_pr(name: string, pr: integer): store.Store, string
  local s = fixture.init_state_repo(name)
  local _root, leaf = fixture.root_with_leaf(s)
  assert(graph.cmd_set(s, leaf, nil, "acme/widgets", "main") == 0)
  local it = check.must(store.load(s, leaf))
  it.reviewer = SESSION
  it.pr = pr
  assert(storewrite.save(s, it, "fixture: review claim + pr for worktree"))
  return s, leaf
end

-- The happy path: a fresh branch and worktree appear at
-- `wt/review-<id8>`, checked out at the PR's head — not `main` — and
-- the verdict line names the path and PR number.
local function test_worktree_review_creates_checkout_at_review_path()
  local checkout = make_pr_checkout("happy", 42)
  local s, leaf = item_with_pr("wtr-happy", 42)
  local id8 = leaf:sub(1, 8)
  local expect = fs.join(fs.dirname(checkout), "wt", "review-" .. id8)
  assert(worktree.cmd_worktree(s, leaf, SESSION, checkout, {}, true, false) == 0)
  assert(fs.is_dir(expect), "the review worktree exists at wt/review-<id8>")
  local content = assert(fs.read(fs.join(expect, "README")))
  assert(content == "pr content\n",
    "checked out the PR's head, not main: " .. content)
  local r = assert(child.run({"git", "rev-parse", "--abbrev-ref", "HEAD"},
      {cwd = expect}))
  assert((r.stdout:gsub("%s+$", "")) == "pr-" .. id8,
    "branched under pr-<id8>: " .. r.stdout)
end

-- Never reuses a review checkout: a second call over the same item
-- refuses outright, same as a builder's.
local function test_worktree_review_refuses_a_repeat()
  local checkout = make_pr_checkout("repeat", 7)
  local s, leaf = item_with_pr("wtr-repeat", 7)
  assert(worktree.cmd_worktree(s, leaf, SESSION, checkout, {}, true, false) == 0)
  assert(worktree.cmd_worktree(s, leaf, SESSION, checkout, {}, true, false) ~= 0,
    "a second --review call over the same item refuses")
end

-- No PR recorded: refused before any git or network call, naming the
-- gap rather than trying (and failing more confusingly) to fetch it.
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

-- An unclaimed review refuses outright, before any git or network
-- call — a build `claim` on the item is never enough on its own, the
-- guard this whole item exists to add: `--review` reads `reviewer`,
-- never `claim`.
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
    "a build claim alone does not satisfy --review's reviewer check")
  assert(not fs.is_dir(expect), "no worktree directory was created")
end

-- A review claim held by a DIFFERENT session refuses too, naming
-- whose claim it actually is.
local function test_worktree_review_refuses_a_different_sessions_claim()
  local checkout = make_pr_checkout("foreign", 5)
  local s, leaf = item_with_pr("wtr-foreign", 5)
  local id8 = leaf:sub(1, 8)
  local expect = fs.join(fs.dirname(checkout), "wt", "review-" .. id8)
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
