#!/usr/bin/env cosmic
-- A mutating verb is independent of the checked-out branch's state at
-- every path — not just the paths it does not own, but ALL of them,
-- now that items are refs rather than files: `sync` is exactly `git
-- fetch --prune` against `refs/heads/items`, `refs/heads/ended` and `refs/heads/board`,
-- which never reads, merges into, or otherwise touches the working
-- tree; neither does a mutation's own commit, or the lost-race
-- recovery. A `_work/**` file mid-edit in the shared checkout —
-- machinery a developer is changing while a verb runs against the
-- same clone — is therefore untouched by any of the three, always,
-- by construction rather than by a targeted fast-forward and a
-- careful reset. `git stash list` stays empty throughout: the
-- machinery must never reach for the stack, which is shared across
-- every worktree of this repo.

local check = require("cosmic.check")
local child = require("cosmic.child")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local publish = require("_work.publish")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

local init_shared = fixture.init_shared
local file_item = fixture.file_item

local counter = 0

--- A fresh deterministic id; later calls sort later.
local function fresh_id(): string
  counter = counter + 1
  return check.must(ksuid.encode(1700000000 + counter, ("\0"):rep(16)))
end

local PARENT = check.must(ksuid.encode(1690000000, ("\1"):rep(16)))

--- A minimal valid workable item, filed directly through the store so
--- a test can commit and publish as two separate steps — `fixture`'s
--- `file_item` does both at once through the `new` verb, which cannot
--- construct a race on its own.
--- @return item.Item
local function make_item(): item.Item
  return check.must(item.decode({
        id = fresh_id(), title = "an item", parent = PARENT,
      }))
end

--- `git stash list`, empty when the shared stack has never been
--- touched — the one escape this machinery must never reach for.
--- @param root string Checkout root
--- @return string Stash listing, "" when empty
local function stash_list(root: string): string
  local r = check.must(child.run({"git", "stash", "list"}, {cwd = root}))
  assert(r.ok, "git stash list failed: " .. r.stderr)
  return (r.stdout:gsub("%s+$", ""))
end

--- Commit and push a `_work/**` file on the checked-out branch, so a
--- later unstaged edit to it is a MODIFICATION of a path git already
--- tracks — the shape that would have been the hazard under the old
--- single-branch design. Items no longer share that branch at all,
--- but the file still has to exist and be tracked for `git status` to
--- have an opinion about it being dirty.
--- @param root string Checkout root
--- @param path string File path relative to root, e.g. "_work/x.tl"
--- @param content string Content
local function seed_tracked_file(root: string, path: string, content: string)
  assert(fs.make_dirs(fs.dirname(fs.join(root, path))))
  assert(fs.write(fs.join(root, path), content))
  fixture.git(root, {"add", "-A"})
  fixture.git(root, {"commit", "-q", "-m", "seed " .. path})
  fixture.git(root, {"push", "-q", "origin", "HEAD"})
end

--- Bring the checked-out branch's working tree level with `origin`,
--- the way a developer would `git pull` the machinery by hand — never
--- `publish.sync`'s job, which only ever fetches `refs/heads/items`,
--- `refs/heads/ended` and `refs/heads/board` and touches no working tree at all.
--- @param root string Checkout root
local function pull_branch(root: string)
  local branch = check.must(child.run({"git", "symbolic-ref", "--short", "HEAD"},
      {cwd = root}))
  assert(branch.ok, "git symbolic-ref failed: " .. branch.stderr)
  fixture.git(root, {"fetch", "-q", "origin"})
  fixture.git(root, {"merge", "-q", "--ff-only",
      "origin/" .. (branch.stdout:gsub("%s+$", ""))})
end

-- A modified-but-uncommitted `_work/**` file sitting dirty in the
-- checkout must not block a sync that has real work to pull in, and a
-- mutation's own commit(s) must never touch it either: `sync` is
-- `fetch --prune` against three ref namespaces, and `save` writes git
-- objects and moves `refs/heads/items/*` directly — neither ever reads or
-- writes the working tree, so there is no mechanism left that COULD
-- disturb an unrelated dirty file, unlike the old fast-forward merge
-- this reasoned about a refusal for.
local function test_a_dirty_unrelated_file_does_not_block_a_mutation()
  local a, b = init_shared("dirty-unrelated")
  seed_tracked_file(a.root, fs.join("_work", "x.tl"), "-- base\n")
  pull_branch(b.root)
  assert(publish.sync(b))
  file_item(a, "a's item, for b to pull in", "")

  local dirty_path = fs.join(b.root, "_work", "x.tl")
  assert(fs.write(dirty_path, "-- an in-progress machinery edit\n"))

  assert(publish.sync(b), "sync must tolerate the unrelated dirty file")
  local after_sync = fs.read(dirty_path)
  assert(after_sync == "-- an in-progress machinery edit\n",
    "the dirty file is byte-identical after a real sync")

  local id = file_item(b, "a workable slice filed over dirt", "")
  assert(check.must(store.load(b, id)).id == id, "the item itself landed")
  local after_mutation = fs.read(dirty_path)
  assert(after_mutation == "-- an in-progress machinery edit\n",
    "the dirty file is byte-identical after the mutation")
  assert(stash_list(b.root) == "", "the shared stash stack is untouched")
end

-- A lost push race, with an unrelated `_work/**` file dirty, must
-- still drop the losing mutation and refuse LOST_RACE — dropping it
-- is a local `git update-ref` on the one item ref that lost its lease
-- plus a `fetch --prune`, neither of which is a working-tree
-- operation, so the old `reset --hard` hazard (every uncommitted
-- MODIFICATION in the checkout wiped, tracked paths included) has no
-- analog left to regress on.
local function test_a_lost_race_preserves_unrelated_dirt()
  local a, b = init_shared("race-dirt")
  seed_tracked_file(a.root, fs.join("_work", "y.tl"), "-- base\n")
  pull_branch(b.root)
  -- A common base both checkouts hold before either mutates, so b's
  -- own commit below is built against state the winner's push makes
  -- stale rather than one that already contains it.
  local base = make_item()
  assert(storewrite.save(a, base, "seed a common base"))
  assert(publish.publish(a))
  assert(publish.sync(b))

  local dirty_path = fs.join(b.root, "_work", "y.tl")
  assert(fs.write(dirty_path, "-- precious uncommitted work\n"))

  -- a wins the race, editing the SAME base item and publishing first —
  -- two brand-new, otherwise-unrelated items would never contend
  -- under the ref layout, so the race needs one shared ref.
  local wa = check.must(store.load(a, base.id))
  wa.title = "a's edit wins"
  assert(storewrite.save(a, wa, "a wins the race"))
  assert(publish.publish(a))

  -- b's edit of the same item, built and pushed against the now-stale
  -- base, loses.
  local wb = check.must(store.load(b, base.id))
  wb.title = "b's edit loses"
  assert(storewrite.save(b, wb, "b loses the race"))
  local ok, err = publish.publish(b)
  assert(not ok and err == store.LOST_RACE,
    "the losing mutation must refuse LOST_RACE: " .. tostring(err))
  assert(check.must(store.load(b, base.id)).title == "a's edit wins",
    "the checkout holds the winner's state")
  local after = fs.read(dirty_path)
  assert(after == "-- precious uncommitted work\n",
    "the dirty file is byte-identical after the lost race")
  assert(stash_list(b.root) == "", "the shared stash stack is untouched")
end

-- The overlapping case is the clearest sign of what moved: under the
-- old single branch, an incoming `_work/**` commit that touched the
-- SAME path as a local uncommitted edit was the one shape a
-- fast-forward could not silently resolve, and `sync` refused it by
-- name. `sync` no longer merges anything — it moves three ref
-- namespaces the working tree has no path under — so the exact same
-- setup (two sides editing `_work/z.tl`, one committed and pushed, one
-- still dirty) no longer refuses at all: sync succeeds, and the dirty
-- edit is left exactly as it was, because nothing about it was ever
-- in sync's way to begin with.
-- A plain `git clone` carries only the branch's refspec; the first
-- `sync` adds the mirror refspecs itself, so a session that never ran
-- `init` still reads the whole board.
local function test_sync_adds_the_mirror_refspecs_to_a_plain_clone()
  local a = init_shared("plain-clone-sync")
  file_item(a, "seen from a plain clone", "")
  local base = fs.dirname(a.root)
  local plain = fs.join(base, "plain")
  local cloned = child.run({"git", "clone", "-q", fs.join(base, "remote.git"), plain})
  assert(cloned ~= nil and cloned.ok, "clone failed")
  local p = check.must(store.open(plain))
  assert(#check.must(store.list(p)) == 0, "a plain clone sees no items before sync")
  assert(publish.sync(p))
  local remote_items = child.run({"git", "for-each-ref", "refs/heads/items"},
    {cwd = fs.join(base, "remote.git")})
  local expected = 0
  for _ in (remote_items and remote_items.stdout or ""):gmatch("[^\n]+") do
    expected = expected + 1
  end
  assert(expected > 0, "the remote holds the filed item")
  assert(#check.must(store.list(p)) == expected,
    "after sync the plain clone lists every remote item")
end

local function test_an_overlapping_dirty_file_no_longer_blocks_sync()
  local a, b = init_shared("dirty-overlap")
  assert(fs.make_dirs(fs.join(a.root, "_work")))
  assert(fs.write(fs.join(a.root, "_work", "z.tl"), "-- base\n"))
  fixture.git(a.root, {"add", "-A"})
  fixture.git(a.root, {"commit", "-q", "-m", "seed _work/z.tl"})
  fixture.git(a.root, {"push", "-q", "origin", "HEAD"})
  pull_branch(b.root)
  assert(publish.sync(b))

  assert(fs.write(fs.join(a.root, "_work", "z.tl"), "-- a's change\n"))
  fixture.git(a.root, {"add", "-A"})
  fixture.git(a.root, {"commit", "-q", "-m", "a changes _work/z.tl"})
  fixture.git(a.root, {"push", "-q", "origin", "HEAD"})

  local dirty_path = fs.join(b.root, "_work", "z.tl")
  assert(fs.write(dirty_path, "-- b's uncommitted change\n"))
  assert(publish.sync(b), "sync no longer reads the working tree at all")
  local after = fs.read(dirty_path)
  assert(after == "-- b's uncommitted change\n",
    "the overlapping edit is preserved — sync never reached it")
  assert(stash_list(b.root) == "", "the shared stash stack is untouched")
end

-- An unreadable remote — the fetch itself fails — is a clean refusal
-- too, never a crash.
local function test_an_unreachable_remote_refuses_cleanly()
  local a = init_shared("unreachable")
  fixture.git(a.root, {"remote", "set-url", "origin",
      fs.join(fixture.tmpdir, "no-such-remote.git")})
  local ok, err = publish.sync(a)
  assert(not ok, "a sync against an unreadable remote must refuse")
  assert(err ~= store.LOST_RACE, "an unreadable remote is not a race: " .. err)
end
