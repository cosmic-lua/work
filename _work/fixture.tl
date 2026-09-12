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
local gitclaim = require("_work.gitclaim")
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
--- nothing filed yet — every item lives as a ref, so there is nothing
--- else to seed. Tests must not inherit mode from topology: local mode
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
-- clones, two pushes/fetches and two `store.init_repo` calls (one of
-- them minting the board item) EVERY time, for a starting shape that
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
      "refs/heads/items/*:refs/heads/items/*",
      "refs/heads/board/*:refs/heads/board/*"})
  assert(refs.set_board_mode(dir1, "remote"))
  assert(refs.fetch_prune(dir1))

  local dir2 = fs.join(base, "clone2")
  git(base, {"clone", "-q", bare, dir2})
  git(dir2, {"config", "core.createObject", "rename"})
  git(dir2, {"config", "maintenance.auto", "false"})
  assert(refs.set_board_mode(dir2, "remote"))
  assert(refs.ensure_refspecs(dir2))
  assert(refs.fetch_prune(dir2))
  assert(store.init_repo(dir2))
  return base
end

--- A bare "remote" with nothing filed yet, plus two remote-mode clones.
--- Initialization itself deliberately performs no transport. The fixture
--- therefore acts as its caller: clone one initializes in explicit local
--- mode, pushes the seed board and format refs, then switches to remote
--- mode and fetches them into the canonical remote-tracking namespace.
--- Clone two fetches those refs before initialization, proving it observes
--- the one existing board rather than minting a second one. No production
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

--- Perform the ordinary Git transport a remote fixture's caller owes after
--- a mutating verb prepared its transaction. Local fixtures have already
--- promoted their mutation and need nothing. Keeping this explicit in the
--- harness makes production's default-print contract visible: no verb gets
--- an ambient or test-only permission to contact a remote.
--- @param s store.Store The fixture store whose plans should be published
local function caller_publish(s: store.Store)
  if refs.board_mode(s.root) == "local" then
    return
  end
  local transactions = check.must(prepared.list(s.root))
  for _, tx in ipairs(transactions) do
    local ok, err = prepared.execute(s.root, prepared.push_argv(tx))
    assert(ok, "caller push failed: " .. err)
  end
  -- Some provider-facing fixtures deliberately give `origin` a GitHub
  -- read URL while retaining their local bare repository as its push URL.
  -- Their board transport is the latter in both directions; using the
  -- display/read URL here would leak a hermetic test onto the network.
  local pushurl = check.must(store.git_ok(s,
      {"remote", "get-url", "--push", "origin"})).stdout:gsub("%s+$", "")
  local fetched, ferr = prepared.execute(s.root, {"git", "fetch", "--prune",
      pushurl,
      "+refs/heads/items/*:refs/remotes/origin/items/*",
      "+refs/heads/ended/*:refs/remotes/origin/ended/*",
      "+refs/heads/board/*:refs/remotes/origin/board/*",
      "+refs/heads/claim-batches/*:refs/remotes/origin/claim-batches/*"})
  assert(fetched, "caller fetch failed: " .. ferr)
  -- Transport is a caller-owned step outside the verb invocation. Drop
  -- any cache handle the test kept open before inspecting the newly fetched
  -- canonical snapshot, matching the fresh process a real next command gets.
  assert(store.close(s))
  local refreshed = check.must(prepared.refresh(s.root))
  for _, result in ipairs(refreshed) do
    assert(result.state == "confirmed", result.detail)
  end
end

--- Fetch board refs as an explicit fixture caller, then let gitboard inspect
--- and rebuild against those already-fetched canonical refs.
--- @param s store.Store The remote fixture store to refresh
local function caller_fetch(s: store.Store)
  if refs.board_mode(s.root) == "local" then
    return
  end
  local pushurl = check.must(store.git_ok(s,
      {"remote", "get-url", "--push", "origin"})).stdout:gsub("%s+$", "")
  local fetched, ferr = prepared.execute(s.root, {"git", "fetch", "--prune",
      pushurl,
      "+refs/heads/items/*:refs/remotes/origin/items/*",
      "+refs/heads/ended/*:refs/remotes/origin/ended/*",
      "+refs/heads/board/*:refs/remotes/origin/board/*",
      "+refs/heads/claim-batches/*:refs/remotes/origin/claim-batches/*"})
  assert(fetched, "caller fetch failed: " .. ferr)
  assert(require("_work.publish").sync(s))
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

local claim_counter = 0

--- Establish one format-4 claim-control transaction in a fixture. Tests use
--- this instead of hand-writing the retired claim fields into item metadata.
--- The helper performs the caller-owned transport for remote fixtures so its
--- return means the same thing as a confirmed claim in production.
local function control_claim(s: store.Store, ids: {string}, holder: string,
    action?: gitclaim.Action, why?: string, product_base?: string): string
  claim_counter = claim_counter + 1
  local mode = refs.board_mode(s.root)
  local requests: {gitclaim.Request} = {}
  local batch = ("fixture-%d-%s"):format(claim_counter, ids[1]:sub(1, 8))
  local now = os.time()
  for _, id in ipairs(ids) do
    local source = mode == "local" and gitclaim.target_item_ref(id)
    or gitclaim.remote_item_ref("origin", id)
    local tip = check.must(refs.read_ref(s.root, source))
    requests[#requests + 1] = {root = s.root, id = id,
      source_ref = source, target_ref = gitclaim.target_item_ref(id),
      remote = "origin", batch = batch, caller = holder,
      action = action or "take",
      product_base = (action or "take") == "take"
      and (product_base or tip) or "",
      force = false, why = why or "", now = now}
  end
  local result = gitclaim.prepare_batch(requests)
  assert(next(result.refused) == nil,
    result.refused.batch or result.refused[ids[1]])
  local p = check.must(result.prepared)
  if mode == "local" then
    assert(prepared.promote_local(s.root, p.transaction))
    assert(store.close(s))
  else
    caller_publish(s)
  end
  return p.batch.commit
end

local function claim_item(s: store.Store, id: string, holder: string,
    product_base?: string): string
  return control_claim(s, {id}, holder, nil, nil, product_base)
end

local function drop_claim(s: store.Store, id: string, holder: string,
    why: string): string
  return control_claim(s, {id}, holder, "drop", why)
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
  action?: gitclaim.Action, why?: string, product_base?: string): string
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
