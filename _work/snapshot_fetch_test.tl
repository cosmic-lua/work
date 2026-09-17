#!/usr/bin/env cosmic
-- `refresh --execute` fetches the board's publication and format refs, and
-- the board remote's default branch beside them, so a session that starts
-- with a refresh holds a current `origin/<default>` for board-repository
-- items before its first claim compares against it. The default is the
-- checkout's cached `origin/HEAD`; nothing is added when none is cached,
-- or when it already lands in a ref the fetch updates.
local check = require("cosmic.check")
local child = require("cosmic.child")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local publish = require("_work.publish")
local repoprofile = require("_work.repoprofile")
local snapshot_fetch = require("_work.snapshot_fetch")

local function rev(root: string, name: string): string
  local r = check.must(child.run({"git", "rev-parse", "--verify", "--quiet",
        name}, {cwd = root}))
  return r.ok and (r.stdout:gsub("%s+$", "")) or ""
end

local function has(argv: {string}, refspec: string): boolean
  for _, value in ipairs(argv) do
    if value == refspec then return true end
  end
  return false
end

--- A checkout whose cached `origin/HEAD` names `branch`, "" for none.
local function checkout_with_default(name: string, branch: string): string
  local root = fs.join(fixture.tmpdir, "snapshot-fetch-" .. name)
  assert(fs.remove_all(root))
  assert(fs.make_dirs(root))
  fixture.git(root, {"init", "-q"})
  if branch ~= "" then
    fixture.git(root, {"symbolic-ref", "refs/remotes/origin/HEAD",
        "refs/remotes/origin/" .. branch})
  end
  return root
end

local function test_refresh_argv_adds_the_cached_default_branch()
  local root = checkout_with_default("main", "main")
  local argv = snapshot_fetch.refresh_argv(root, "origin", "state", "/endpoint")
  local base = snapshot_fetch.fetch_branch_argv("origin", "state", "/endpoint")
  assert(#argv == #base + 1, "exactly one refspec joins the publication fetch")
  for index, value in ipairs(base) do
    assert(argv[index] == value, "the state and format refspecs are unchanged")
  end
  assert(argv[#argv] == "+refs/heads/main:refs/remotes/origin/main",
    "the default branch is forced into the board remote's tracking namespace")
end

local function test_refresh_argv_without_a_cached_default_is_the_publication_fetch()
  local root = checkout_with_default("none", "")
  assert(repoprofile.default_base(root) == "")
  local argv = snapshot_fetch.refresh_argv(root, "origin", "state")
  assert(table.concat(argv, " ")
    == table.concat(snapshot_fetch.fetch_branch_argv("origin", "state"), " "),
    "no cached origin/HEAD means nothing to add")
end

-- A board whose HEAD is its state branch already fetches that ref: one
-- atomic fetch may not update the same tracking ref twice.
local function test_refresh_argv_never_fetches_one_tracking_ref_twice()
  local root = checkout_with_default("state", "state")
  local argv = snapshot_fetch.refresh_argv(root, "origin", "state")
  assert(#argv == #snapshot_fetch.fetch_branch_argv("origin", "state"))
  assert(has(argv, "+refs/heads/state:refs/remotes/origin/state"))
  local redirected = snapshot_fetch.refresh_argv(root, "origin", "validation/x")
  assert(#redirected == #argv, "a redirected publication branch still lands "
    .. "in the state tracking ref, so the default cannot join it")
end

-- The executed path: a clone's `refresh --execute` lands the board remote's
-- default branch beside the state refs, and follows its advance.
local function test_refresh_execute_fetches_the_board_default_branch()
  local a, b = fixture.init_shared("refresh-default")
  fixture.git(a.root, {"symbolic-ref", "HEAD", "refs/heads/main"})
  assert(fs.write(fs.join(a.root, "README.md"), "machinery\n"))
  fixture.git(a.root, {"add", "-A"})
  fixture.git(a.root, {"commit", "-q", "-m", "machinery on main"})
  fixture.git(a.root, {"push", "-q", "origin", "HEAD:refs/heads/main"})
  local first = rev(a.root, "HEAD")
  fixture.git(b.root, {"symbolic-ref", "refs/remotes/origin/HEAD",
      "refs/remotes/origin/main"})
  assert(rev(b.root, "refs/remotes/origin/main") == "",
    "the clone starts without the default branch's tracking ref")
  assert(publish.sync(b), "a default refresh performs no transport")
  assert(rev(b.root, "refs/remotes/origin/main") == "",
    "without --execute the default branch is not fetched either")
  assert(publish.sync(b, true))
  assert(rev(b.root, "refs/remotes/origin/main") == first,
    "refresh --execute lands the board remote's default branch")

  assert(fs.write(fs.join(a.root, "README.md"), "machinery\nadvanced\n"))
  fixture.git(a.root, {"add", "-A"})
  fixture.git(a.root, {"commit", "-q", "-m", "advance main"})
  fixture.git(a.root, {"push", "-q", "origin", "HEAD:refs/heads/main"})
  local second = rev(a.root, "HEAD")
  assert(second ~= first)
  assert(publish.sync(b, true))
  assert(rev(b.root, "refs/remotes/origin/main") == second,
    "a later refresh --execute follows the default branch's advance")
  assert(rev(b.root, "refs/heads/main") == "",
    "refresh touches only tracking refs, never a local branch")
end
