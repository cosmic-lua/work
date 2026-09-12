#!/usr/bin/env cosmic
-- Properties specific to the ref layout itself, as opposed to
-- `_work/store_test.tl`'s save/load/publish mechanics: independent
-- item leases, atomicity across every ref one save touches, and the
-- ended-item ref move. Its own file so `store_test.tl` stays under the
-- line cap; the fixed-process-count properties split further into
-- `_work/storeref_processcount_test.tl` to keep this file under the cap
-- too and let those from-scratch board seedings run in their own process.

local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local flow = require("_work.flow")
local fs = require("cosmic.fs")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local publish = require("_work.publish")
local refs = require("_work.refs")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

local tmpdir = os.getenv("TEST_TMPDIR") or "/tmp"

-- See `_work/store_test.tl`'s header for why this is needed under the
-- build fence.
local hermetic_config < const > = fs.join(tmpdir, "gitconfig-empty")
assert(fs.write(hermetic_config, ""))
assert(env.set("GIT_CONFIG_GLOBAL", hermetic_config))
assert(env.set("GIT_CONFIG_NOSYSTEM", "1"))

local function git(cwd: string, argv: {string})
  local full: {string} = {"git", "-c", "user.email=test@example.com",
    "-c", "user.name=test", "-c", "core.createObject=rename"}
  for _, a in ipairs(argv) do
    full[#full + 1] = a
  end
  local r = check.must(child.run(full, {cwd = cwd}))
  assert(r.ok, "git " .. table.concat(argv, " ") .. " failed: " .. r.stderr)
end

-- `store.init_repo` runs a handful of git processes (init, the board
-- commit) that never vary between calls — build the result once per
-- process and copy it, instead of paying that cost on every case.
local state_template: string | nil = nil

--- A fresh local-only state repo, with its `refs/heads/board/format` marker.
local function init_state_repo(name: string): string
  if state_template == nil then
    state_template = fs.join(tmpdir, "storeref-template")
    assert(fs.remove_all(state_template))
    assert(fs.make_dirs(state_template))
    assert(store.init_repo(state_template))
  end
  local root = fs.join(tmpdir, "storeref-" .. name)
  assert(fs.remove_all(root))
  assert(fs.copy_tree(state_template, root))
  return root
end

-- Building the bare-plus-clones shape from scratch pays a bare init, one
-- clone (plus a fetch and a push) per requested clone, and one
-- `store.init_repo` each — the same sequence every time for a given
-- clone count. Cache one built template per count and `fs.copy_tree`
-- it per call, rewriting each clone's `origin` afterward since it
-- names the template's own `remote.git` by absolute path.
local shared_templates: {integer: string} = {}

local function build_shared_template(clones: integer): string
  local base = fs.join(tmpdir, "storeref-shared-template-" .. clones)
  assert(fs.remove_all(base))
  assert(fs.make_dirs(base))
  local bare = fs.join(base, "remote.git")
  git(base, {"init", "-q", "--bare", bare})
  git(bare, {"config", "core.createObject", "rename"})
  for i = 1, clones do
    local dir = fs.join(base, ("clone%d"):format(i))
    git(base, {"clone", "-q", bare, dir})
    git(dir, {"config", "core.createObject", "rename"})
    if i > 1 then
      assert(refs.ensure_refspecs(dir))
      assert(refs.fetch_prune(dir))
    end
    assert(store.init_repo(dir))
    if i == 1 then
      -- Initialization only creates local refs. The fixture explicitly
      -- performs the caller-owned bootstrap transport and fetches the
      -- canonical remote-tracking refs back.
      git(dir, {"push", "-q", "--atomic", "origin",
          "refs/heads/items/*:refs/heads/items/*",
          "refs/heads/board/*:refs/heads/board/*"})
      assert(refs.fetch_prune(dir))
    end
  end
  return base
end

--- A bare "remote" with nothing filed yet, plus n clones.
local function init_shared(name: string, clones: integer): string, {string}
  if shared_templates[clones] == nil then
    shared_templates[clones] = build_shared_template(clones)
  end
  local base = fs.join(tmpdir, "storeref-shared-" .. name)
  assert(fs.remove_all(base))
  assert(fs.copy_tree(shared_templates[clones], base))
  local bare = fs.join(base, "remote.git")
  local out: {string} = {}
  for i = 1, clones do
    local dir = fs.join(base, ("clone%d"):format(i))
    git(dir, {"remote", "set-url", "origin", bare})
    out[#out + 1] = dir
  end
  return bare, out
end

local counter = 0

--- A fresh deterministic id; later calls sort later.
local function fresh_id(): string
  counter = counter + 1
  return check.must(ksuid.encode(1700000000 + counter, ("\0"):rep(16)))
end

local PARENT = check.must(ksuid.encode(1690000000, ("\1"):rep(16)))

--- A minimal valid workable item. Claims are projected from shared
--- claim batches, so these ref-layout tests use ordinary item fields.
local function make_item(title?: string): item.Item
  return check.must(item.decode({
        id = fresh_id(), title = title or "an item", parent = PARENT,
      }))
end

-- Even with enough already-claimed items to exceed the former shared
-- WIP cap, two sessions changing different item refs can both land.
-- No board-wide seq lease serializes independent work acquisition.
local function test_independent_item_mutations_do_not_share_a_global_lease()
  local _, clones = init_shared("cas", 2)
  local a = check.must(store.open(clones[1]))
  for i = 1, flow.DOING_LIMIT - 1 do
    assert(storewrite.save(a, make_item(("busy-%d"):format(i)),
        ("busy %d"):format(i)))
  end
  local mine = make_item()
  local yours = make_item()
  assert(storewrite.save(a, mine, "new mine"))
  assert(storewrite.save(a, yours, "new yours"))
  assert(publish.publish(a, true))
  local b = check.must(store.open(clones[2]))
  assert(publish.sync(b, true))

  -- Both sides read the whole board (as `flow.doing_refusal`'s own
  -- caller does) before deciding to take — this is what a bounded
  -- gate's precondition looks like, and what makes `set_bounded`
  -- honest here rather than a bare flag with nothing behind it.
  assert(store.list(a))
  local ia = check.must(store.load(a, mine.id))
  ia.title = "mine by session-a"
  assert(storewrite.save(a, ia, "retitle mine by session-a"))
  assert(publish.publish(a, true))

  assert(store.list(b))
  local ib = check.must(store.load(b, yours.id))
  ib.title = "yours by session-b"
  assert(storewrite.save(b, ib, "retitle yours by session-b"))
  local ok, err = publish.publish(b, true)
  assert(ok, "independent item refs both land: " .. err)
  assert(publish.sync(a, true))
  local back = check.must(store.load(b, yours.id))
  assert(back.title == "yours by session-b", "the second independent edit lands")
  local winner = check.must(store.load(a, mine.id))
  assert(winner.title == "mine by session-a",
    "the first independent edit remains visible")
end

-- The atomicity the push provides, not the commit object: a save that
-- touches two items (a decomposition's child and the parent it
-- de-phases) makes two commits, and when the remote has moved under
-- ONE of them, the WHOLE push is refused. The staged multi-ref
-- transaction stays intact for diagnosis; canonical refs expose the
-- winner after the caller fetches.
local function test_publish_is_atomic_across_every_ref_a_save_touched()
  local _, clones = init_shared("atomic-multiref", 2)
  local a = check.must(store.open(clones[1]))
  local parent = make_item("original parent")
  assert(storewrite.save(a, parent, "new parent"))
  assert(publish.publish(a, true))
  local b = check.must(store.open(clones[2]))
  assert(publish.sync(b, true))

  -- a moves the parent forward, out from under b — a distinct,
  -- checkable change (the title), so the assertion below cannot be
  -- satisfied by coincidence.
  local pa = check.must(store.load(a, parent.id))
  pa.title = "retitled by a"
  assert(storewrite.save(a, pa, "set parent title"))
  assert(publish.publish(a, true))

  -- b, still on the stale parent, writes a new child AND de-phases
  -- the parent in the same mutation — two commits, one save.
  local pb = check.must(store.load(b, parent.id))
  local kid = make_item()
  pb.title = "retitled by b"
  assert(storewrite.save(b, kid, "new kid", nil, {pb}))
  local ok = publish.publish(b, true)
  assert(not ok, "the stale multi-ref push must be refused")
  local synced, err = publish.sync(b, true)
  assert(not synced and err:find("lost their ref lease", 1, true) ~= nil,
    "refresh classifies the staged multi-ref race: " .. tostring(err))
  assert(store.load(b, kid.id) == nil,
    "the brand-new child never lands without its parent's commit")
  local after = check.must(store.load(b, parent.id))
  assert(after.title == "retitled by a",
    "the parent shows the winner's own state, not b's dropped edit: "
    .. after.title)
end

--- Every ref name under `refs/heads/items`/`refs/heads/ended`.
local function item_refnames(root: string): {string}
  local r = check.must(child.run(
      {"git", "for-each-ref", "--format=%(refname)", "refs/heads/items", "refs/heads/ended"},
      {cwd = root}))
  assert(r.ok, "git for-each-ref failed: " .. r.stderr)
  local out: {string} = {}
  for line in r.stdout:gmatch("([^\n]+)") do
    out[#out + 1] = line
  end
  return out
end

-- A resolution SETS `resolution` on whatever ref the item is already
-- on — it never moves the ref. The pushing credential every session
-- carries can create and update a branch but never delete one, so an
-- ended-move (create `refs/heads/ended/<id>`, delete
-- `refs/heads/items/<id>`, one push) could land the create half and
-- lose the delete half, leaving the id filed under both namespaces;
-- not moving the ref at all is what makes that impossible.
local function test_resolution_stays_on_the_items_ref_and_sets_resolution()
  local root = init_state_repo("no-move")
  local s = check.must(store.open(root))
  local it = make_item()
  assert(storewrite.save(s, it, "new item"))
  local before = item_refnames(root)
  local found_open = false
  for _, r in ipairs(before) do
    if r == "refs/heads/items/" .. it.id then
      found_open = true
    end
  end
  assert(found_open, "the item starts on refs/heads/items")

  it.resolution = "completed"
  assert(storewrite.save(s, it, "done " .. it.id:sub(1, 8)))
  local after = item_refnames(root)
  local still_open, now_ended = false, false
  for _, r in ipairs(after) do
    if r == "refs/heads/items/" .. it.id then
      still_open = true
    end
    if r == "refs/heads/ended/" .. it.id then
      now_ended = true
    end
  end
  assert(still_open, "refs/heads/items still names it — a resolution never moves the ref")
  assert(not now_ended, "refs/heads/ended gains no new entry")
  local loaded = check.must(store.load(s, it.id))
  assert(loaded.resolution == "completed", "load still finds it, resolved")
  -- Both commits landed on the SAME ref — its own history, never split
  -- across two refs the way an ended-move would have.
  local events = check.must(publish.history(s, it.id))
  assert(#events == 2, "the ref's own history holds both commits: "
    .. #events)
end

-- A legacy item — filed under `refs/heads/ended/<id>` before this rule,
-- the way the cutover import's 722 items are — stays there when it is
-- resolved (or corrected) again: `ended/` is read, and written in
-- place when an item already there changes, but a resolution never
-- files a NEW entry under it.
local function test_a_legacy_ended_item_stays_under_ended_when_resolved()
  local root = init_state_repo("legacy-ended")
  local s = check.must(store.open(root))
  local it = make_item()
  assert(storewrite.save(s, it, "new item"))
  local sha = (check.must(child.run(
        {"git", "rev-parse", "refs/heads/items/" .. it.id}, {cwd = root})).stdout
    :gsub("%s+$", ""))
  -- Hand-file it under refs/heads/ended, the way the pre-cutover
  -- layout did, before this test ever resolves it.
  git(root, {"update-ref", "refs/heads/ended/" .. it.id, sha})
  git(root, {"update-ref", "-d", "refs/heads/items/" .. it.id})

  local s2 = check.must(store.open(root))
  local loaded = check.must(store.load(s2, it.id))
  loaded.resolution = "completed"
  assert(storewrite.save(s2, loaded, "done " .. it.id:sub(1, 8)))

  local after = item_refnames(root)
  local still_ended, now_items = false, false
  for _, r in ipairs(after) do
    if r == "refs/heads/ended/" .. it.id then
      still_ended = true
    end
    if r == "refs/heads/items/" .. it.id then
      now_items = true
    end
  end
  assert(still_ended, "the legacy item stays under refs/heads/ended")
  assert(not now_items, "resolving it never creates a refs/heads/items entry")
  local reloaded = check.must(store.load(s2, it.id))
  assert(reloaded.resolution == "completed", "the resolution field is set")
end

-- The fixed-process-count properties for `list`, `show` (bare), and
-- `show ID` live in `_work/storeref_processcount_test.tl`.
