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
local stateclaim = require("_work.stateclaim")
local statewrite = require("_work.statewrite")
local statepublish = require("_work.statepublish")
local staging = require("_work.statestaging")
local graph = require("_work.gitgraph")
local idxmod = require("_work.index")
local irank = require("_work.index_rank")
local item = require("_work.item")
local prepared = require("_work.prepared")
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
-- `GIT_CONFIG_PARAMETERS`/`GIT_CONFIG_COUNT` carry config past any config FILE,
-- where an ambient `url.*.insteadOf` rewrites what a test reads back: empty too.
local hermetic_config < const > = fs.join(tmpdir, "gitconfig-empty")
assert(fs.write(hermetic_config, ""))
assert(env.set("GIT_CONFIG_GLOBAL", hermetic_config))
assert(env.set("GIT_CONFIG_NOSYSTEM", "1"))
assert(env.set("GIT_CONFIG_PARAMETERS", ""))
assert(env.set("GIT_CONFIG_COUNT", "0"))

local READY_SPEC < const > = [[
## Change

Do exactly this.

## Non-goals

Not that.
]]

-- `git worktree add` can fail with `could not open
-- '.git/worktrees/<name>/locked' for writing: No such file or
-- directory` — an ENOENT racing git's own creation of
-- `<gitdir>/worktrees/<name>/` before it opens the lock file inside
-- it. Never seen locally, and never for any other git subcommand or
-- `worktree add` failure text, so retrying the identical argv a
-- couple of times clears the race without masking a real failure.
local WORKTREE_LOCKED_PATTERN < const > =
"worktrees/[^/']+/locked' for writing: No such file or directory"
local WORKTREE_ADD_RETRIES < const > = 2

--- Run one git command in `cwd`, failing loudly — fixture setup. A
--- `git worktree add` that fails with the transient
--- `.git/worktrees/<name>/locked` race is retried, with the identical
--- argv, up to `WORKTREE_ADD_RETRIES` times; any other failure — from
--- `worktree add` or any other subcommand — fails on the first
--- attempt exactly as before.
local function git(cwd: string, argv: {string})
  local full: {string} = {"git", "-c", "user.email=test@example.com",
    "-c", "user.name=test", "-c", "core.createObject=rename"}
  for _, a in ipairs(argv) do
    full[#full + 1] = a
  end
  local is_worktree_add = argv[1] == "worktree" and argv[2] == "add"
  local retries = is_worktree_add and WORKTREE_ADD_RETRIES or 0
  local r = check.must(child.run(full, {cwd = cwd}))
  while not r.ok and retries > 0
  and r.stderr:find(WORKTREE_LOCKED_PATTERN, 1, false) ~= nil do
    retries = retries - 1
    r = check.must(child.run(full, {cwd = cwd}))
  end
  assert(r.ok, "git " .. table.concat(argv, " ") .. " failed: " .. r.stderr)
end

-- `init_state_repo` is by far the hottest fixture call in this test
-- process (every verb test starts from one) and `git init` plus
-- `store.init_repo`'s board-item commit are the same handful of git
-- processes every single time, on an otherwise-empty directory. Build
-- that starting state once per process and `fs.copy_tree` it for every
-- later call instead of re-running `git init`/`store.init_repo` — the
-- template is a plain directory tree with no absolute-path state (a
-- freshly `git init`ed, remote-less repo), so copying it is exactly as
-- good as reinitializing.
local state_template: string | nil = nil

local function build_state_template(): string
  local root = fs.join(tmpdir, "verbs-template")
  assert(fs.remove_all(root))
  assert(fs.make_dirs(root))
  git(root, {"init", "-q"})
  -- `store.init_repo` writes its board commit through plumbing
  -- (`gitobj.commit_tree`/`refs.update_ref`), which never runs git's
  -- own `run_auto_maintenance()` — only porcelain commands do — so
  -- this template is not exposed today. Disabled anyway, at zero cost,
  -- so a future change to that write path (or to this fixture) cannot
  -- reopen the race `fs.copy_tree` can lose against a maintenance run's
  -- transient `.git/objects/maintenance.lock` (see `build_shared_template`
  -- below, and `_work/commit_flow_fixture.tl`, for where this is a
  -- confirmed, not merely defensive, fix).
  git(root, {"config", "maintenance.auto", "false"})
  assert(refs.set_board_mode(root, "local"))
  assert(store.init_repo(root))
  return root
end

--- A fresh explicitly local-only state repo: `store.init_repo` (a bare git init
--- plus the `refs/heads/board/format` marker every board now carries),
--- with one board item under `items/` in the state tree. Tests must not
--- inherit mode from topology: local mode
--- is a supported simulation/migration surface, not merely "no origin".
local function init_state_repo(name: string): store.Store
  if state_template == nil then
    state_template = build_state_template()
  end
  local root = fs.join(tmpdir, "verbs-" .. name)
  assert(fs.remove_all(root))
  assert(fs.copy_tree(state_template, root))
  return check.must(store.open(root))
end

-- `init_shared`'s bare-plus-two-clones setup pays a bare init, two
-- clones, a push and two fetches, and one `store.init_repo` call
-- minting the board item EVERY time, for a starting shape that
-- never varies. Build it once per process and copy the whole `base`
-- tree for later calls; only the two clones' `origin` URLs need
-- rewriting afterward, since they point at the template's own
-- `remote.git` by absolute path.
local shared_template: string | nil = nil

local function build_shared_template(): string
  local base = fs.join(tmpdir, "verbs-shared-template")
  assert(fs.remove_all(base))
  assert(fs.make_dirs(base))
  local bare = fs.join(base, "remote.git")
  git(base, {"init", "-q", "--bare", bare})
  git(bare, {"config", "core.createObject", "rename"})
  -- `git push`'s receive-pack runs server-side `git gc --auto --quiet`
  -- after every push into this bare repo (confirmed via `GIT_TRACE=1`)
  -- — the same transient-lock race as a porcelain commit's
  -- `maintenance.auto`, just the legacy `gc.auto` mechanism instead,
  -- triggered from the OTHER end of the push below. Disabled before
  -- the first push lands.
  git(bare, {"config", "receive.autogc", "false"})
  local dir1 = fs.join(base, "clone1")
  git(base, {"clone", "-q", bare, dir1})
  git(dir1, {"config", "core.createObject", "rename"})
  git(dir1, {"config", "maintenance.auto", "false"})
  assert(refs.set_board_mode(dir1, "local"))
  assert(store.init_repo(dir1))
  git(dir1, {"push", "--atomic", "origin",
      "refs/heads/state:refs/heads/state",
      "refs/heads/board/format:refs/heads/board/format"})
  git(bare, {"symbolic-ref", "HEAD", "refs/heads/state"})
  assert(refs.set_board_mode(dir1, "remote"))
  assert(refs.fetch_prune(dir1))

  local dir2 = fs.join(base, "clone2")
  git(base, {"clone", "-q", bare, dir2})
  git(dir2, {"config", "core.createObject", "rename"})
  git(dir2, {"config", "maintenance.auto", "false"})
  assert(refs.set_board_mode(dir2, "remote"))
  assert(refs.ensure_refspecs(dir2))
  assert(refs.fetch_prune(dir2))
  return base
end

--- A bare "remote" with nothing filed yet, plus two remote-mode clones.
--- Initialization itself deliberately performs no transport. The fixture
--- therefore acts as its caller: clone one initializes in explicit local
--- mode, pushes the seed board and format refs, then switches to remote
--- mode and fetches them into the canonical remote-tracking namespace.
--- Clone two fetches those refs and opens the existing board. No production
--- path gains implicit network behavior from this test scaffolding.
local function init_shared(name: string): store.Store, store.Store
  if shared_template == nil then
    shared_template = build_shared_template()
  end
  local base = fs.join(tmpdir, "verbs-shared-" .. name)
  assert(fs.remove_all(base))
  assert(fs.copy_tree(shared_template, base))
  local bare = fs.join(base, "remote.git")
  local dir1, dir2 = fs.join(base, "clone1"), fs.join(base, "clone2")
  git(dir1, {"remote", "set-url", "origin", bare})
  git(dir2, {"remote", "set-url", "origin", bare})
  local s1 = check.must(store.open(dir1))
  local s2 = check.must(store.open(dir2))
  return s1, s2
end

--- Fetch both activation refs from the fixture's local transport destination.
local function fetch_state(s: store.Store)
  local remote = refs.board_remote(s.root)
  -- Provider fixtures retain a local push URL even when their read URL is GitHub.
  local pushurl = check.must(store.git_ok(s,
      {"remote", "get-url", "--push", remote})).stdout:gsub("%s+$", "")
  local argv = statepublish.fetch_argv(remote)
  argv[4] = pushurl
  local fetched, err = prepared.execute(s.root, argv)
  assert(fetched, "caller fetch failed: " .. err)
end

--- Publish and confirm prepared native transitions as the explicit caller.
--- Local fixtures already promoted their mutations and need no transport.
local function caller_publish(s: store.Store)
  if refs.board_mode(s.root) == "local" then assert(statepublish.publish(s)); return end
  for _, receipt in ipairs(check.must(staging.list(s.root, "prepared"))) do
    local ok, err = statepublish.execute(s.root, receipt)
    assert(ok, "caller push failed: " .. err)
  end
  fetch_state(s)
  local synced, err = statepublish.sync(s)
  assert(synced, "caller confirmation failed: " .. err)
end

--- Fetch the native state and activation marker as an explicit fixture caller,
--- then confirm transactions and refresh the store's canonical snapshot.
local function caller_fetch(s: store.Store)
  if refs.board_mode(s.root) == "local" then assert(statepublish.sync(s)); return end
  fetch_state(s)
  assert(statepublish.sync(s))
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
  caller_publish(s)
  for _, i in ipairs(check.must(store.list(s))) do
    if not before[i.id] then
      return i.id
    end
  end
  error("new filed nothing: " .. title)
end

--- Count published board mutations on the canonical state's first-parent chain.
local function commits(s: store.Store): integer
  local head = check.must(statepublish.head(s.root, refs.board_remote(s.root)))
  if head == refs.ZERO_SHA then return 0 end
  local result = check.must(store.git_ok(s, {"rev-list", "--first-parent", "--count", head}))
  return math.tointeger(tonumber((result.stdout:gsub("%s+$", "")))) or -1
end

--- The author email on the latest published native board commit.
local function commit_author_email(s: store.Store): string
  local head = check.must(statepublish.head(s.root, refs.board_remote(s.root)))
  assert(head ~= refs.ZERO_SHA, "no commits on the board yet")
  local result = check.must(store.git_ok(s, {"log", "-1", "--format=%ae", head}))
  return (result.stdout:gsub("%s+$", ""))
end

--- A spec sidecar meeting the ready bar, through the spec verb.
local function give_spec(s: store.Store, id: string)
  local path = fs.join(tmpdir, "ready-spec.md")
  assert(fs.write(path, READY_SPEC))
  assert(gitspec.cmd_spec(s, id, path) == 0, "spec should be accepted")
  caller_publish(s)
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
  caller_publish(s)
  return root, file_item(s, "a workable slice", root)
end

--- Establish a native claim transition and perform caller-owned publication.
--- Return the first member's stable acquisition identity, including on renew/drop.
local function control_claim(s: store.Store, ids: {string}, holder: string,
    action?: stateclaim.Action, why?: string, product_base?: string): string
  local requests: {stateclaim.Request} = {}
  for _, id in ipairs(ids) do
    check.must(store.load(s, id))
    local tip = s.leased_sha[id] or s.state_head
    requests[#requests + 1] = {id = id,
      product_base = (action or "take") == "take" and (product_base or tip) or ""}
  end
  local result = stateclaim.prepare(s.root, s.state_head, requests, action or "take",
    holder, os.time(), false, why or "")
  assert(next(result.refused) == nil, result.refused.batch or result.refused[ids[1]])
  for _, dependency in ipairs(result.dependencies) do
    s.state_paths[dependency.path], s.state_reads[dependency.path] = dependency.id, dependency.id
  end
  local session, op, bounded = s.session, s.op, s.bounded
  s.session, s.op, s.bounded = holder, action == "renew" and "renew" or action == "drop" and "drop" or "claim", false
  local ok, err = statewrite.transition(s, result.changes,
    stateclaim.message(action or "take", holder, why or ""), result.publish_by)
  assert(ok, err)
  assert(statepublish.publish(s))
  caller_publish(s)
  s.session, s.op, s.bounded = session, op, bounded
  return result.members[1].claim_root
end

local function claim_item(s: store.Store, id: string, holder: string,
    product_base?: string): string
  return control_claim(s, {id}, holder, nil, nil, product_base)
end

local function drop_claim(s: store.Store, id: string, holder: string,
    why: string): string
  return control_claim(s, {id}, holder, "drop", why)
end

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
  caller_publish: function(s: store.Store)
  caller_fetch: function(s: store.Store)
  github_origin: function(s: store.Store, slug: string)
  file_item: function(s: store.Store, title: string,
  parent: string): string
  commits: function(s: store.Store): integer
  commit_author_email: function(s: store.Store): string
  give_spec: function(s: store.Store, id: string)
  root_with_leaf: function(s: store.Store): string, string
  control_claim: function(s: store.Store, ids: {string}, holder: string,
  action?: stateclaim.Action, why?: string, product_base?: string): string
  claim_item: function(s: store.Store, id: string, holder: string,
  product_base?: string): string
  drop_claim: function(s: store.Store, id: string, holder: string,
  why: string): string
  make_index: function(items: {item.Item}): idxmod.Index
end

local M: fixture = {
  READY_SPEC = READY_SPEC,
  tmpdir = tmpdir,
  git = git,
  init_state_repo = init_state_repo,
  init_shared = init_shared,
  caller_publish = caller_publish,
  caller_fetch = caller_fetch,
  github_origin = github_origin,
  file_item = file_item,
  commits = commits,
  commit_author_email = commit_author_email,
  give_spec = give_spec,
  root_with_leaf = root_with_leaf,
  control_claim = control_claim,
  claim_item = claim_item,
  drop_claim = drop_claim,
  make_index = make_index,
}

return M
