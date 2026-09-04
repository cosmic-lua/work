#!/usr/bin/env cosmic
-- `store.init_repo`/`open`: preparing and opening a state repository.
-- Split from `_work/store_test.tl` to keep that file under its line
-- cap; the save/load/publish mechanics live there.

local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local store = require("_work.store")

local tmpdir = os.getenv("TEST_TMPDIR") or "/tmp"

-- Git reads a global (and system) config before it does anything, and
-- a config it cannot READ is fatal under the build fence — see
-- `_work/store_test.tl`'s header for the full reasoning; restated
-- here because this file also runs git directly.
local hermetic_config < const > = fs.join(tmpdir, "gitconfig-empty")
assert(fs.write(hermetic_config, ""))
assert(env.set("GIT_CONFIG_GLOBAL", hermetic_config))
assert(env.set("GIT_CONFIG_NOSYSTEM", "1"))

--- Run one git command in `cwd`, failing the test loudly if it does
--- not exit zero — fixture setup, not the code under test.
local function git(cwd: string, argv: {string})
  local full: {string} = {"git", "-c", "user.email=test@example.com",
    "-c", "user.name=test", "-c", "core.createObject=rename"}
  for _, a in ipairs(argv) do
    full[#full + 1] = a
  end
  local r = check.must(child.run(full, {cwd = cwd}))
  assert(r.ok, "git " .. table.concat(argv, " ") .. " failed: " .. r.stderr)
end

-- init_repo prepares a fresh directory whole: a git repository
-- (created when none is there) — there is no `items/` directory to
-- create, since every item lives as a ref, not a file.
local function test_init_repo_creates_a_fresh_git_repo()
  local root = fs.join(tmpdir, "init-fresh")
  assert(fs.remove_all(root))
  assert(store.init_repo(root))
  assert(fs.is_present(fs.join(root, ".git")), "a git repo now exists")
  assert(check.must(store.open(root)).root == root,
    "open accepts exactly what init_repo left")
end

-- A directory that is already a git repo (no `.git` to create) is
-- still accepted, and a second call over the same tree is a no-op yes
-- rather than a refusal.
local function test_init_repo_is_idempotent_over_an_existing_git()
  local root = fs.join(tmpdir, "init-existing")
  assert(fs.remove_all(root))
  assert(fs.make_dirs(root))
  git(root, {"init", "-q"})
  assert(store.init_repo(root))
  assert(store.init_repo(root), "a second call over the same tree is a yes")
end

-- A clone that already has an `origin` gets the mirror refspecs ADDED
-- to `remote.origin.fetch` — the whole lost-race recovery depends on
-- every clone fetching the same three patterns.
local function test_init_repo_writes_fetch_refspecs_when_origin_exists()
  local bare = fs.join(tmpdir, "init-origin.git")
  assert(fs.remove_all(bare))
  git(tmpdir, {"init", "-q", "--bare", "init-origin.git"})
  local dir = fs.join(tmpdir, "init-origin-clone")
  assert(fs.remove_all(dir))
  git(tmpdir, {"clone", "-q", bare, "init-origin-clone"})
  assert(store.init_repo(dir))
  local r = check.must(child.run({"git", "config", "--get-all", "remote.origin.fetch"},
      {cwd = dir}))
  assert(r.ok, "git config failed: " .. r.stderr)
  assert(r.stdout:find("refs/items/%*:refs/items/%*") ~= nil, r.stdout)
  assert(r.stdout:find("refs/ended/%*:refs/ended/%*") ~= nil, r.stdout)
  assert(r.stdout:find("refs/board/%*:refs/board/%*") ~= nil, r.stdout)
  -- ADDED, not substituted: the clone's own default refspec for its
  -- checked-out branch survives, so a plain `git pull` on the
  -- machinery keeps working after `init_repo` runs.
  assert(r.stdout:find("refs/heads/*:refs/remotes/origin/*", 1, true) ~= nil,
    "the default branch refspec is untouched: " .. r.stdout)
  -- Idempotent: a second call adds nothing more.
  assert(store.init_repo(dir))
  local r2 = check.must(child.run({"git", "config", "--get-all", "remote.origin.fetch"},
      {cwd = dir}))
  assert(r2.stdout == r.stdout, "a second init_repo adds nothing new")
end
