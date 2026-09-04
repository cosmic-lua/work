#!/usr/bin/env cosmic
-- `store.init_repo`/`open`: preparing and opening a state repository.
-- Split from `_work/store_test.tl` to keep that file under its line
-- cap; the save/load/publish mechanics live there.

local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local format = require("_work.format")
local fs = require("cosmic.fs")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
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
  assert(r.stdout:find("refs/heads/items/%*:refs/heads/items/%*") ~= nil, r.stdout)
  assert(r.stdout:find("refs/heads/ended/%*:refs/heads/ended/%*") ~= nil, r.stdout)
  assert(r.stdout:find("refs/heads/board/%*:refs/heads/board/%*") ~= nil, r.stdout)
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

-- `init_repo` writes `refs/heads/board/format` on a fresh repository — the
-- exact blob `_work.format.blob` gives, at the one path `format`.
local function test_init_repo_writes_the_format_marker()
  local root = fs.join(tmpdir, "init-format")
  assert(fs.remove_all(root))
  assert(store.init_repo(root))
  local r = check.must(child.run({"git", "cat-file", "-p", "refs/heads/board/format:format"},
      {cwd = root}))
  assert(r.ok, "the marker blob reads back: " .. r.stderr)
  assert(r.stdout == format.blob(), "got: " .. r.stdout)
end

--- The `refs/heads/board/format` sha, "" when the ref does not exist.
local function format_sha(root: string): string
  local r = child.run({"git", "rev-parse", "--verify", "-q", "refs/heads/board/format"},
    {cwd = root})
  if r == nil or not r.ok then
    return ""
  end
  return (r.stdout:gsub("%s+$", ""))
end

--- Hand-write `refs/heads/board/format`'s `format` blob to `text` — plumbing
--- a real reader (`gitread.list`) would meet on a board this tool
--- disagrees with, never `_work.store`'s own writer.
--- @param root string The state repository
--- @param text string The blob content to write
local function rewrite_format(root: string, text: string)
  local blob = check.must(child.run({"git", "hash-object", "-w", "--stdin"},
      {cwd = root, stdin = text}))
  assert(blob.ok, "hash-object failed: " .. blob.stderr)
  local blob_sha = (blob.stdout:gsub("%s+$", ""))
  local tree = check.must(child.run({"git", "mktree"},
      {cwd = root, stdin = ("100644 blob %s\tformat\n"):format(blob_sha)}))
  assert(tree.ok, "mktree failed: " .. tree.stderr)
  local tree_sha = (tree.stdout:gsub("%s+$", ""))
  local argv: {string} = {"git", "-c", "user.email=test@example.com",
    "-c", "user.name=test", "commit-tree", tree_sha, "-m", "hand-edited format"}
  local old = format_sha(root)
  if old ~= "" then
    argv[#argv + 1] = "-p"
    argv[#argv + 1] = old
  end
  local commit = check.must(child.run(argv, {cwd = root}))
  assert(commit.ok, "commit-tree failed: " .. commit.stderr)
  git(root, {"update-ref", "refs/heads/board/format", (commit.stdout:gsub("%s+$", ""))})
end

--- One filed item, so a format check has a board that "already
--- carries items" to be asked about.
--- @param s store.Store The store to file into
local function seed_one_item(s: store.Store)
  local id = check.must(ksuid.encode(1700000000, ("\0"):rep(16)))
  local it = check.must(item.decode({id = id, title = "a seeded item"}))
  assert(store.save(s, it, "seed"))
end

-- A board whose marker names a version other than the one this tool
-- knows is refused by the whole-board read — naming both versions, so
-- the message alone says which side is behind.
local function test_list_refuses_a_wrong_format_version()
  local root = fs.join(tmpdir, "format-wrong-version")
  assert(fs.remove_all(root))
  assert(store.init_repo(root))
  local s = check.must(store.open(root))
  seed_one_item(s)
  rewrite_format(root, "2\n")
  local all, lerr = store.list(s)
  assert(all == nil, "a board on a version this tool does not know is refused")
  assert(lerr:find("2", 1, true) ~= nil and lerr:find(format.CURRENT, 1, true) ~= nil,
    "the refusal names both versions: " .. lerr)
end

-- A board with items but NO format marker at all reads as the old
-- layout it is — refused, never silently trusted.
local function test_list_refuses_a_missing_marker_with_items_present()
  local root = fs.join(tmpdir, "format-missing")
  assert(fs.remove_all(root))
  assert(store.init_repo(root))
  local s = check.must(store.open(root))
  seed_one_item(s)
  git(root, {"update-ref", "-d", "refs/heads/board/format"})
  local all, lerr = store.list(s)
  assert(all == nil, "a board with items and no marker is refused")
  assert(lerr:find("format", 1, true) ~= nil, "got: " .. lerr)
end

-- The same board, empty (nothing ever filed), with no marker either:
-- `init_repo` is what writes one, and a scratch repo before that has
-- run has nothing else to be inconsistent with — so this is fine, not
-- a refusal.
local function test_list_accepts_a_missing_marker_on_an_empty_board()
  local root = fs.join(tmpdir, "format-missing-empty")
  assert(fs.remove_all(root))
  assert(store.init_repo(root))
  git(root, {"update-ref", "-d", "refs/heads/board/format"})
  local s = check.must(store.open(root))
  local all = check.must(store.list(s))
  assert(#all == 0, "an empty board with no marker still reads: " .. #all)
end
