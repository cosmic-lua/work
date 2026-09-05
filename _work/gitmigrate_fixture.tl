--- A hand-built layout-1 board — `refs/heads/board/format` holding
--- `1`, item refs whose trees carry `edges/beats/<id>`,
--- `edges/blocked_by/<id>`, and a `held` blob, no board item — for
--- `_work.gitmigrate_test`. Built with the same low-level
--- `_work.gitobj`/`_work.refs` plumbing `_work.itemtree_test`'s own
--- old-layout test uses, since nothing else writes this shape any
--- more. Required only by `*_test.tl` files, the same convention
--- `_work.fixture` follows.
local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local gitobj = require("_work.gitobj")
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local ksuid = require("_work.ksuid")
local refs = require("_work.refs")
local store = require("_work.store")

local tmpdir = os.getenv("TEST_TMPDIR") or "/tmp"

-- See `_work/fixture.tl`'s header for why this is fatal-not-skipped
-- under the build fence.
local hermetic_config < const > = fs.join(tmpdir, "gitconfig-empty")
assert(fs.write(hermetic_config, ""))
assert(env.set("GIT_CONFIG_GLOBAL", hermetic_config))
assert(env.set("GIT_CONFIG_NOSYSTEM", "1"))

--- Run one git command in `cwd`, failing loudly — fixture setup.
--- @param cwd string
--- @param argv {string}
local function git(cwd: string, argv: {string})
  local full: {string} = {"git", "-c", "user.email=test@example.com",
    "-c", "user.name=test", "-c", "core.createObject=rename"}
  for _, a in ipairs(argv) do
    full[#full + 1] = a
  end
  local r = check.must(child.run(full, {cwd = cwd}))
  assert(r.ok, "git " .. table.concat(argv, " ") .. " failed: " .. r.stderr)
end

local counter = 0

--- A fresh, deterministically ordered id: later calls sort later, the
--- same device `_work.itemtree_test.fresh_id` uses, so age tie-breaks
--- in the fixture below are predictable.
--- @return string
local function fresh_id(): string
  counter = counter + 1
  return check.must(ksuid.encode(1700000000 + counter, ("\0"):rep(16)))
end

--- Write `refs/heads/board/format` holding `1` — the layout `migrate`
--- reads past and every other verb refuses on.
--- @param root string
local function write_format_1(root: string)
  local blob_sha = check.must(gitobj.hash_object_write(root, "1\n"))
  local tree_sha = check.must(gitobj.mktree_write(root,
      {{mode = "100644", otype = "blob", sha = blob_sha, name = "format"}}))
  local commit_sha = check.must(gitobj.commit_tree(root, {tree = tree_sha, parents = {},
        message = "format 1", author_name = "Claude", author_email = "noreply@anthropic.com",
        committer_name = "Claude", committer_email = "noreply@anthropic.com"}))
  assert(refs.update_ref(root, "refs/heads/board/format", commit_sha, refs.ZERO_SHA))
end

--- One `edges/<kind>` subtree from an id -> content map; a kind with
--- nothing in it contributes no entry at all, matching what a real
--- writer would have left.
--- @param root string
--- @param kind_trees {gitobj.TreeEntry} Accumulator, mutated in place
--- @param name string "beats" or "blocked_by"
--- @param idmap {string: string} | nil Target/blocker id -> content
local function add_kind_tree(root: string, kind_trees: {gitobj.TreeEntry},
    name: string, idmap: {string: string} | nil)
  if idmap == nil or next(idmap) == nil then
    return
  end
  local entries: {gitobj.TreeEntry} = {}
  for tid, content in pairs(idmap) do
    local sha = check.must(gitobj.hash_object_write(root, content or ""))
    entries[#entries + 1] = {mode = "100644", otype = "blob", sha = sha, name = tid}
  end
  local ksha = check.must(gitobj.mktree_write(root, entries))
  kind_trees[#kind_trees + 1] = {mode = "40000", otype = "tree", sha = ksha, name = name}
end

--- File one old-layout item: `meta` (via `itemtree.encode_meta`, so
--- this fixture never drifts from the real meta shape), an optional
--- `held` blob, and an `edges` subtree from whichever of `beats`/
--- `blocked_by` were given. No `order` blob — layout 1 predates it.
--- @param root string
--- @param it item.Item Only the scalar fields matter; `other_edges` is ignored here
--- @param beats {string: string} | nil This item's own `beats` targets
--- @param blocked_by {string: string} | nil This item's own `blocked_by` targets
--- @param held boolean Whether to write a `held` marker blob
local function file_old_item(root: string, it: item.Item, beats: {string: string},
    blocked_by: {string: string}, held: boolean)
  local entries: {gitobj.TreeEntry} = {}
  local meta_sha = check.must(gitobj.hash_object_write(root, itemtree.encode_meta(it)))
  entries[#entries + 1] = {mode = "100644", otype = "blob", sha = meta_sha, name = "meta"}
  if held then
    local held_sha = check.must(gitobj.hash_object_write(root, ""))
    entries[#entries + 1] = {mode = "100644", otype = "blob", sha = held_sha, name = "held"}
  end
  local kind_trees: {gitobj.TreeEntry} = {}
  add_kind_tree(root, kind_trees, "beats", beats)
  add_kind_tree(root, kind_trees, "blocked_by", blocked_by)
  if #kind_trees > 0 then
    local edges_sha = check.must(gitobj.mktree_write(root, kind_trees))
    entries[#entries + 1] = {mode = "40000", otype = "tree", sha = edges_sha, name = "edges"}
  end
  local tree_sha = check.must(gitobj.mktree_write(root, entries))
  local commit_sha = check.must(gitobj.commit_tree(root, {tree = tree_sha, parents = {},
        message = "seed " .. it.title, author_name = "Claude",
        author_email = "noreply@anthropic.com", committer_name = "Claude",
        committer_email = "noreply@anthropic.com"}))
  assert(refs.update_ref(root, "refs/heads/items/" .. it.id, commit_sha, refs.ZERO_SHA))
end

--- A minimal item: a fresh id, a title, a parent ("" for a root), and
--- an optional resolution — every other field defaults to zero.
--- @param title string
--- @param parent string
--- @param resolution string | nil
--- @return item.Item
local function make_item(title: string, parent: string, resolution?: string): item.Item
  return check.must(item.decode({id = fresh_id(), title = title, parent = parent,
        resolution = resolution or ""}))
end

--- Every id `_work.gitmigrate_test` asserts against, named for the
--- scenario it covers.
local record Scenario
  r1: string
  r2: string
  r3: string
  r4: string
  r5: string
  c1: string
  c2: string
  c3: string
  w1: string
  b1: string
  r7: string
  w3: string
  b2: string
  w4: string
  b3: string
  done_waiter: string
  done_blocker: string
  held_root: string
end

--- Seed a full layout-1 board into `root` (bare or not — every write
--- here is plumbing, no working tree needed): the format marker at
--- `1`, and one item per line of `_work.gitmigrate`'s own test
--- roster — three roots in a `beats` chain, a root with no edges, two
--- siblings under a root sharing a `beats` edge, a cross-subtree
--- `beats` edge off one of them, a blocker with one waiter, a blocker
--- with two waiters under different roots, a blocker already the
--- waiter's child, a done item with a `blocked_by` edge, and one held
--- root.
--- @param root string
--- @return Scenario
local function seed(root: string): Scenario
  write_format_1(root)

  -- Three roots, a beats chain: r1 beats r2 beats r3.
  local r1 = make_item("first in the chain", "")
  local r2 = make_item("second in the chain", "")
  local r3 = make_item("third in the chain", "")
  file_old_item(root, r1, {[r2.id] = ""}, {}, false)
  file_old_item(root, r2, {[r3.id] = ""}, {}, false)
  file_old_item(root, r3, {}, {}, false)

  -- A root with no edges at all.
  local r4 = make_item("an unrelated root", "")
  file_old_item(root, r4, {}, {}, false)

  -- A root with two children sharing a beats edge, and a third child
  -- (w2 below, the two-waiters scenario) that names no edge of its
  -- own and so stays unranked among them.
  local r5 = make_item("a root being decomposed", "")
  local c1 = make_item("the higher-ranked child", r5.id)
  local c2 = make_item("the lower-ranked child", r5.id)
  local w2 = make_item("an unranked sibling, also a waiter", r5.id)
  file_old_item(root, r5, {}, {}, false)
  -- c1's beats names a sibling (c2, applied) and a cross-subtree
  -- target (r1, not a sibling — dropped).
  file_old_item(root, c1, {[c2.id] = "", [r1.id] = ""}, {}, false)
  file_old_item(root, c2, {}, {}, false)

  -- A blocker with exactly one open waiter.
  local w1 = make_item("the sole waiter", "")
  local b1 = make_item("the blocker w1 alone waits on", "")
  file_old_item(root, w1, {}, {[b1.id] = "the API is not stable yet"}, false)
  file_old_item(root, b1, {}, {}, false)

  -- A blocker with two open waiters under different roots: w2 (under
  -- r5, the older root) outranks w3 (under r7, the younger one) once
  -- both are unranked-by-age at the board level.
  local r7 = make_item("a younger root", "")
  local w3 = make_item("the losing waiter", r7.id)
  local b2 = make_item("the contested blocker", "")
  file_old_item(root, w2, {}, {[b2.id] = "w2 also waits"}, false)
  file_old_item(root, r7, {}, {}, false)
  file_old_item(root, w3, {}, {[b2.id] = "w3 also waits"}, false)
  file_old_item(root, b2, {}, {}, false)

  -- A blocker already filed as the waiter's own child.
  local w4 = make_item("a waiter whose blocker already lives under it", "")
  local b3 = make_item("a blocker already parented", w4.id)
  file_old_item(root, w4, {}, {[b3.id] = "already close"}, false)
  file_old_item(root, b3, {}, {}, false)

  -- A done item with a blocked_by edge: dropped, not re-parented.
  local done_waiter = make_item("a done item that still names a blocker",
    "", "completed")
  local done_blocker = make_item("the blocker a done item named", "")
  file_old_item(root, done_waiter, {}, {[done_blocker.id] = "moot now"}, false)
  file_old_item(root, done_blocker, {}, {}, false)

  -- One held root.
  local held_root = make_item("a held root", "")
  file_old_item(root, held_root, {}, {}, true)

  return {
    r1 = r1.id, r2 = r2.id, r3 = r3.id, r4 = r4.id, r5 = r5.id,
    c1 = c1.id, c2 = c2.id, c3 = w2.id, w1 = w1.id, b1 = b1.id,
    r7 = r7.id, w3 = w3.id, b2 = b2.id, w4 = w4.id, b3 = b3.id,
    done_waiter = done_waiter.id, done_blocker = done_blocker.id,
    held_root = held_root.id,
  }
end

--- A fresh local-only repo (`git init`, no `store.init_repo` — that
--- would mint a board through the very format check this fixture
--- means to bypass), seeded and opened.
--- @param name string
--- @return store.Store
--- @return Scenario
local function init_solo(name: string): store.Store, Scenario
  local root = fs.join(tmpdir, "gitmigrate-" .. name)
  assert(fs.remove_all(root))
  assert(fs.make_dirs(root))
  git(root, {"init", "-q"})
  local scenario = seed(root)
  return check.must(store.open(root)), scenario
end

--- A bare "remote" seeded directly (plumbing needs no working tree),
--- plus two clones with the mirror refspecs already fetched — the
--- lost-race test's starting point: both clones observe the SAME
--- pre-migration state before either one moves.
--- @param name string
--- @return store.Store
--- @return store.Store
--- @return Scenario
local function init_shared(name: string): store.Store, store.Store, Scenario
  local base = fs.join(tmpdir, "gitmigrate-shared-" .. name)
  assert(fs.remove_all(base))
  assert(fs.make_dirs(base))
  local bare = fs.join(base, "remote.git")
  git(base, {"init", "-q", "--bare", bare})
  git(bare, {"config", "core.createObject", "rename"})
  local scenario = seed(bare)
  local function clone(dir_name: string): store.Store
    local dir = fs.join(base, dir_name)
    git(base, {"clone", "-q", bare, dir})
    git(dir, {"config", "core.createObject", "rename"})
    assert(refs.ensure_refspecs(dir))
    assert(refs.fetch_prune(dir))
    return check.must(store.open(dir))
  end
  local a = clone("clone1")
  local b = clone("clone2")
  return a, b, scenario
end

local record gitmigrate_fixture
  type Scenario = Scenario
  seed: function(root: string): Scenario
  init_solo: function(name: string): store.Store, Scenario
  init_shared: function(name: string): store.Store, store.Store, Scenario
end

local M: gitmigrate_fixture = {
  seed = seed,
  init_solo = init_solo,
  init_shared = init_shared,
}

return M
