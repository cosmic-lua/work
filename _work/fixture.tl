--- Scratch state repositories for the verb tests: a hermetic git
--- environment, a fresh store, a ready-bar-passing spec, and the two
--- shapes every verb test starts from — a goal with one workable leaf
--- under it, and a pair of clones over one bare remote.
---
--- A module rather than a copy in each test file: the harness is a
--- hundred lines of git plumbing, and two copies of it drift the way
--- any duplicate does. It is required only by `*_test.tl`.
local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local gitspec = require("_work.gitspec")
local graph = require("_work.gitgraph")
local idxmod = require("_work.index")
local irank = require("_work.index_rank")
local item = require("_work.item")
local rank = require("_work.gitrank")
local readddl = require("_work.readddl")
local refs = require("_work.refs")
local store = require("_work.store")

local tmpdir = os.getenv("TEST_TMPDIR") or "/tmp"

-- Git reads a global (and system) config before it does anything, and
-- a config it cannot READ is fatal, not skipped: under the build
-- fence the home directory is outside the granted trees, so every git
-- call here — the fixtures' and the store's own — dies on
-- `unable to access '~/.gitconfig'`. Pointing this process at an
-- empty config makes the fixtures depend on no ambient state at all,
-- which is what a test of git behaviour wants regardless of the
-- fence. The store itself is deliberately NOT hermetic: a real
-- session's push needs the user's credentials and config.
local hermetic_config < const > = fs.join(tmpdir, "gitconfig-empty")
assert(fs.write(hermetic_config, ""))
assert(env.set("GIT_CONFIG_GLOBAL", hermetic_config))
assert(env.set("GIT_CONFIG_NOSYSTEM", "1"))

local READY_SPEC < const > = [[
## Change
Do exactly this.
## Non-goals
Not that.
]]

--- Run one git command in `cwd`, failing loudly — fixture setup.
local function git(cwd: string, argv: {string})
  local full: {string} = {"git", "-c", "user.email=test@example.com",
    "-c", "user.name=test", "-c", "core.createObject=rename"}
  for _, a in ipairs(argv) do
    full[#full + 1] = a
  end
  local r = check.must(child.run(full, {cwd = cwd}))
  assert(r.ok, "git " .. table.concat(argv, " ") .. " failed: " .. r.stderr)
end

--- A fresh local-only state repo: `store.init_repo` (a bare git init
--- plus the `refs/heads/board/format` marker every board now carries),
--- nothing filed yet — every item lives as a ref, so there is nothing
--- else to seed.
local function init_state_repo(name: string): store.Store
  local root = fs.join(tmpdir, "verbs-" .. name)
  assert(fs.remove_all(root))
  assert(fs.make_dirs(root))
  assert(store.init_repo(root))
  return check.must(store.open(root))
end

--- A bare "remote" with nothing filed yet, plus two clones — each
--- carrying the mirror refspecs `store.init_repo` writes once it sees
--- their `origin`, the same way a real `gitboard init` after a clone
--- would. The first clone's `init_repo` mints the board (titled
--- "board") and best-effort pushes it; the second clone FETCHES before
--- its own `init_repo` runs, so it finds that board already there
--- instead of minting a second one — `init_repo` has no way to see a
--- remote's state on its own, only what this checkout has already
--- fetched.
local function init_shared(name: string): store.Store, store.Store
  local base = fs.join(tmpdir, "verbs-shared-" .. name)
  assert(fs.remove_all(base))
  assert(fs.make_dirs(base))
  local bare = fs.join(base, "remote.git")
  git(base, {"init", "-q", "--bare", bare})
  git(bare, {"config", "core.createObject", "rename"})
  local dir1 = fs.join(base, "clone1")
  git(base, {"clone", "-q", bare, dir1})
  git(dir1, {"config", "core.createObject", "rename"})
  assert(store.init_repo(dir1))
  local s1 = check.must(store.open(dir1))

  local dir2 = fs.join(base, "clone2")
  git(base, {"clone", "-q", bare, dir2})
  git(dir2, {"config", "core.createObject", "rename"})
  assert(refs.ensure_refspecs(dir2))
  assert(refs.fetch_prune(dir2))
  assert(store.init_repo(dir2))
  local s2 = check.must(store.open(dir2))
  return s1, s2
end

--- Point a store's origin at GitHub for READING while its pushes keep
--- landing where they did: `url` becomes the https form of `slug`, so
--- `gh.slug(s, nil)` resolves the board's owner, and `pushurl` keeps
--- the local bare path a clone from `init_shared` already publishes
--- to. Opt-in — a fixture that never asks about the owner is
--- unchanged — and applied to a clone, never to a local-only store:
--- `publish` fetches only after a rejected push, so nothing here
--- ever reaches the network.
--- @param s store.Store A store cloned from a local bare remote
--- @param slug string The `owner/name` the board is to read as its own
local function github_origin(s: store.Store, slug: string)
  local r = check.must(child.run({"git", "remote", "get-url", "origin"},
      {cwd = s.root}))
  assert(r.ok, "the store has an origin to keep pushing to: " .. r.stderr)
  local bare = (r.stdout:gsub("%s+$", ""))
  git(s.root, {"remote", "set-url", "origin",
      ("https://github.com/%s.git"):format(slug)})
  git(s.root, {"remote", "set-url", "--push", "origin", bare})
end

--- File an item through `new` and return its id. A KSUID orders by
--- its one-second timestamp, so items minted inside the same second
--- sort by their random half — "the newest item" is not something a
--- test can read off the sorted list. The set difference is.
local function file_item(s: store.Store, title: string,
    parent: string): string
  local before: {string: boolean} = {}
  for _, i in ipairs(check.must(store.list(s))) do
    before[i.id] = true
  end
  assert(graph.cmd_new(s, title, parent, nil, "") == 0,
    "new should be accepted: " .. title)
  for _, i in ipairs(check.must(store.list(s))) do
    if not before[i.id] then
      return i.id
    end
  end
  error("new filed nothing: " .. title)
end

--- Every ref name under `refs/heads/items` and `refs/heads/ended` in a store.
--- @param s store.Store The store
--- @return {string} The refnames
local function item_refnames(s: store.Store): {string}
  local r = check.must(child.run(
      {"git", "for-each-ref", "--format=%(refname)", "refs/heads/items", "refs/heads/ended"},
      {cwd = s.root}))
  assert(r.ok, "git for-each-ref failed: " .. r.stderr)
  local out: {string} = {}
  for line in r.stdout:gmatch("([^\n]+)") do
    out[#out + 1] = line
  end
  return out
end

--- How many DISTINCT commits the whole board carries, across every
--- item and ended ref — every save makes at least one brand-new
--- commit object per item it touches, so this is "how many item
--- writes has the board seen" the way a single working-tree HEAD's
--- commit count once was. A mutation that touches `also` items now
--- contributes one commit PER item it writes, not one commit overall
--- — the atomicity moved from the git commit object to the push.
--- @param s store.Store The store
--- @return integer The count, 0 for an empty board
local function commits(s: store.Store): integer
  local refnames = item_refnames(s)
  if #refnames == 0 then
    return 0
  end
  local argv: {string} = {"rev-list", "--count"}
  for _, r in ipairs(refnames) do
    argv[#argv + 1] = r
  end
  local r = check.must(child.run({"git", table.unpack(argv)}, {cwd = s.root}))
  assert(r.ok, "git rev-list failed: " .. r.stderr)
  return math.tointeger(tonumber((r.stdout:gsub("%s+$", "")))) or -1
end

--- The most recently committed item (or lanes) mutation's author
--- email — what a reader (GitHub's verified badge, a `git log`)
--- actually sees a board commit as, whichever ref it landed on.
--- @param s store.Store The store
--- @return string The author email of the newest commit on the board
local function commit_author_email(s: store.Store): string
  local r = check.must(child.run(
      {"git", "for-each-ref", "--format=%(refname)", "refs/heads/items", "refs/heads/ended",
        "refs/heads/board"}, {cwd = s.root}))
  assert(r.ok, "git for-each-ref failed: " .. r.stderr)
  local refnames: {string} = {}
  for line in r.stdout:gmatch("([^\n]+)") do
    refnames[#refnames + 1] = line
  end
  assert(#refnames > 0, "no commits on the board yet")
  local argv: {string} = {"log", "-1", "--format=%ae"}
  for _, ref in ipairs(refnames) do
    argv[#argv + 1] = ref
  end
  local log = check.must(child.run({"git", table.unpack(argv)}, {cwd = s.root}))
  assert(log.ok, "git log failed: " .. log.stderr)
  return (log.stdout:gsub("%s+$", ""))
end

--- A spec sidecar meeting the ready bar, through the spec verb.
local function give_spec(s: store.Store, id: string)
  local path = fs.join(tmpdir, "ready-spec.md")
  assert(fs.write(path, READY_SPEC))
  assert(gitspec.cmd_spec(s, id, path) == 0, "spec should be accepted")
end

--- An organizing outcome (filed under the board by `new`'s own default,
--- since `parent` is "") with one workable leaf under it, both filed
--- through `new`. The outcome is RANKED last among the board's
--- outcomes so that it — and everything beneath it — is ranked: an
--- unranked outcome would leave its leaf unpullable, which is the rule
--- under test elsewhere, not a property of this fixture.
local function root_with_leaf(s: store.Store): string, string
  local root = file_item(s, "an outcome", "")
  local _peer = file_item(s, "a lesser outcome", "")
  assert(rank.cmd_rank(s, root, "", "", true) == 0,
    "rank should be accepted")
  return root, file_item(s, "a workable slice", root)
end

-- A decomposition writes the child AND the parent it de-phases —
-- each its own commit now, but one atomic push, so half of it
-- reaching the board would never leave a parent off the board with
-- nothing decomposing it.

--- An in-memory index over `items`, with `_work.index_rank` AND
--- `_work.readddl`'s views applied, in that order — `readddl`'s own
--- views join against `rank_path`/`dense_rank`, so those must exist
--- first. What a pure report or decision test builds instead of a
--- real store: no git, no cache file, just the same derived rows a
--- live board's cache would carry.
--- @param items {item.Item} The board
--- @return idxmod.Index
local function make_index(items: {item.Item}): idxmod.Index
  local idx = check.must(idxmod.open(items))
  check.must(irank.ensure_views(idx))
  check.must(readddl.ensure_views(idx))
  return idx
end

local record fixture
  READY_SPEC: string
  tmpdir: string
  git: function(cwd: string, argv: {string})
  init_state_repo: function(name: string): store.Store
  init_shared: function(name: string): store.Store, store.Store
  github_origin: function(s: store.Store, slug: string)
  file_item: function(s: store.Store, title: string,
  parent: string): string
  commits: function(s: store.Store): integer
  commit_author_email: function(s: store.Store): string
  give_spec: function(s: store.Store, id: string)
  root_with_leaf: function(s: store.Store): string, string
  make_index: function(items: {item.Item}): idxmod.Index
end

local M: fixture = {
  READY_SPEC = READY_SPEC,
  tmpdir = tmpdir,
  git = git,
  init_state_repo = init_state_repo,
  init_shared = init_shared,
  github_origin = github_origin,
  file_item = file_item,
  commits = commits,
  commit_author_email = commit_author_email,
  give_spec = give_spec,
  root_with_leaf = root_with_leaf,
  make_index = make_index,
}

return M
