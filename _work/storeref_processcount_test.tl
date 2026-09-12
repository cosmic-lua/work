#!/usr/bin/env cosmic
-- `list`'s and `show`'s fixed git-process-count properties, split out of
-- `_work/storeref_test.tl` to keep that file under the line cap and to
-- let this file's three from-scratch board seedings (3 then 12 items,
-- twice per test) run in their own process alongside it rather than
-- serialized after it.

local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local gitshow = require("_work.gitshow")
local gitview = require("_work.gitview")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
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
    state_template = fs.join(tmpdir, "storeref-processcount-template")
    assert(fs.remove_all(state_template))
    assert(fs.make_dirs(state_template))
    -- Pre-`init` and disable `maintenance.auto` so `store.init_repo`
    -- (which sees `.git` already there and skips its own `git init`)
    -- never has a chance to run with it enabled. Its board commit is
    -- plumbing (`gitobj.commit_tree`), which never triggers git's own
    -- `run_auto_maintenance()`, so this template is not exposed today
    -- — disabled anyway, at zero cost, since a maintenance run's
    -- transient `.git/objects/maintenance.lock` is a race `fs.copy_tree`
    -- can lose on every later call. `_work/commit_flow_fixture.tl` has
    -- the confirmed version of this fix.
    git(state_template, {"init", "-q"})
    git(state_template, {"config", "maintenance.auto", "false"})
    assert(store.init_repo(state_template))
  end
  local root = fs.join(tmpdir, "storeref-processcount-" .. name)
  assert(fs.remove_all(root))
  assert(fs.copy_tree(state_template, root))
  return root
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

-- `list` runs a FIXED number of git processes regardless of board
-- size, whatever path it takes: `store.list` itself pays one
-- `for-each-ref` snapshot for its own freshness digest, then reads
-- through the board cache (`_work.cache.open`) — on a board this test
-- deliberately keeps stale (every `seed` below writes through
-- `storewrite.save` directly, bypassing `_work.gitgate.commit_and_publish`'s
-- incremental hooks), every measured call pays a full cache rebuild:
-- one more `for-each-ref` (`_work.gitread.list`'s own snapshot), one
-- `cat-file --batch` SESSION for every item's meta/held/order/edges,
-- every edge kind's own subtree content, and every content blob (a
-- blocked_by or other-kind reason) — one persistent process for that
-- whole session, never one per item or per round — one more
-- `cat-file --batch` for every item's spec sidecar, one `git log` for
-- the events table, and a final `for-each-ref` for the digest the
-- rebuild records. Six processes total, not growing with item count.
-- Counted by racing `git` itself: a counting wrapper ahead of the real
-- binary on PATH, so every invocation `_work.refs`/`_work.gitobj`/
-- `_work.events` make is caught, not just the ones this test happens
-- to know the argv for.
local function test_list_process_count_is_constant_as_items_grow()
  local root = init_state_repo("process-count")
  local s = check.must(store.open(root))
  local real_git = check.must(child.run({"sh", "-c", "command -v git"})).stdout
  real_git = (real_git:gsub("%s+$", ""))
  local wrapdir = fs.join(tmpdir, "storeref-git-wrap")
  assert(fs.remove_all(wrapdir))
  assert(fs.make_dirs(wrapdir))
  local counter_file = fs.join(tmpdir, "storeref-git-count.txt")
  assert(fs.write(counter_file, ""))
  assert(fs.write(fs.join(wrapdir, "git"),
      ("#!/bin/sh\nprintf x >> '%s'\nexec '%s' \"$@\"\n"):format(counter_file, real_git)))
  assert(fs.set_mode(fs.join(wrapdir, "git"), fs.octal("755")))

  --- File one item with a blocker, so `list`'s edge-kind and
  --- content-blob processes actually run.
  local function seed(n: integer)
    local ids: {string} = {}
    for i = 1, n do
      local it = make_item()
      assert(storewrite.save(s, it, ("seed %d"):format(i)))
      ids[#ids + 1] = it.id
    end
    for i = 2, n do
      local it = check.must(store.load(s, ids[i]))
      it.other_edges = {blocked_by = {[ids[1]] = "seeding order"}}
      assert(storewrite.save(s, it, "block"))
    end
    -- These writes go straight through `storewrite.save`, bypassing
    -- `gate.commit_and_publish`'s own cache patch — so, unlike a real
    -- mutation verb, nothing here keeps `s.index` in step with what
    -- was just seeded. Closing it is this test's own stand-in for
    -- that: the next `store.list` reopens fresh rather than reading
    -- back whatever a still-open connection saw before this seeding.
    local _cok, _cerr = store.close(s)
  end

  --- How many `git` invocations one `store.list` makes, with the
  --- wrapper ahead of the real binary on PATH for this call alone.
  local function list_process_count(): integer
    assert(fs.write(counter_file, ""))
    local old_path = os.getenv("PATH") or ""
    assert(env.set("PATH", wrapdir .. ":" .. old_path, true))
    check.must(store.list(s))
    assert(env.set("PATH", old_path, true))
    return #(fs.read(counter_file) or "")
  end

  seed(3)
  local small = list_process_count()
  seed(12)
  local big = list_process_count()
  assert(small > 0, "the wrapper caught at least one invocation")
  assert(small == big,
    ("list's process count must not grow with item count: %d (3 items) vs "
      .. "%d (15 items)"):format(small, big))
  assert(small <= 6, ("at most 6 processes: got %d"):format(small))
end

--- The whole-board render (`gitboard show`, bare) reads every open
--- item's spec sidecar for the bar checks it prints — `store.read_specs`
--- makes that one batch, not one `cat-file -p` per item, so the git
--- process count `cmd_status` spends must stay flat as the board grows.
local function test_whole_board_show_process_count_is_constant_as_items_grow()
  local root = init_state_repo("show-process-count")
  local s = check.must(store.open(root))
  local real_git = check.must(child.run({"sh", "-c", "command -v git"})).stdout
  real_git = (real_git:gsub("%s+$", ""))
  local wrapdir = fs.join(tmpdir, "storeref-show-git-wrap")
  assert(fs.remove_all(wrapdir))
  assert(fs.make_dirs(wrapdir))
  local counter_file = fs.join(tmpdir, "storeref-show-git-count.txt")
  assert(fs.write(counter_file, ""))
  assert(fs.write(fs.join(wrapdir, "git"),
      ("#!/bin/sh\nprintf x >> '%s'\nexec '%s' \"$@\"\n"):format(counter_file, real_git)))
  assert(fs.set_mode(fs.join(wrapdir, "git"), fs.octal("755")))

  local function seed(n: integer)
    for i = 1, n do
      local it = make_item()
      assert(storewrite.save(s, it, ("seed %d"):format(i),
          ("spec body for item %d"):format(i)))
    end
  end

  --- How many `git` invocations one `gitview.cmd_status` (bare `show`)
  --- makes, with the wrapper ahead of the real binary on PATH.
  local function show_process_count(): integer
    assert(fs.write(counter_file, ""))
    local old_path = os.getenv("PATH") or ""
    assert(env.set("PATH", wrapdir .. ":" .. old_path, true))
    gitview.cmd_status(s)
    assert(env.set("PATH", old_path, true))
    return #(fs.read(counter_file) or "")
  end

  -- Warm the cache once against the EMPTY board first, so both
  -- measured calls below find a cache file already there (and
  -- therefore pay the same digest-guard process `_work.cache.open`
  -- spends on every call) — every `seed` here writes through
  -- `storewrite.save` directly, bypassing the incremental hooks
  -- `_work.gitgate.commit_and_publish` normally fires, so each
  -- measured call below finds the cache stale and rebuilds it, a
  -- fixed process count regardless of how many items that rebuild
  -- reads.
  show_process_count()
  seed(3)
  local small = show_process_count()
  seed(12)
  local big = show_process_count()
  assert(small > 0, "the wrapper caught at least one invocation")
  assert(small == big,
    ("show's process count must not grow with item count: %d (3 items) vs "
      .. "%d (15 items)"):format(small, big))
end

--- `show ID` reads every OTHER open item's spec sidecar too, for
--- `_work.overlap`'s Change-section collision check — one batch
--- (`store.read_specs`), not one `cat-file -p` per sibling, so the
--- process count `gitshow.cmd_show` spends on one item must stay flat
--- as the number of siblings around it grows. `gitshow.cmd_show` now
--- reads the item list through `_work.cache`/`_work.cachequery` (see
--- `test_whole_board_show_process_count_is_constant_as_items_grow`,
--- above, for the identical caveat on `cmd_status`): the warm-up call
--- below and the seeding through `storewrite.save` directly (bypassing
--- the incremental hooks `_work.gitgate.commit_and_publish` normally
--- fires) means both measured calls find the cache already there but
--- stale, and pay the same fixed rebuild cost, regardless of how many
--- items that rebuild reads.
local function test_show_one_item_process_count_is_constant_as_siblings_grow()
  local root = init_state_repo("show-id-process-count")
  local s = check.must(store.open(root))
  local real_git = check.must(child.run({"sh", "-c", "command -v git"})).stdout
  real_git = (real_git:gsub("%s+$", ""))
  local wrapdir = fs.join(tmpdir, "storeref-show-id-git-wrap")
  assert(fs.remove_all(wrapdir))
  assert(fs.make_dirs(wrapdir))
  local counter_file = fs.join(tmpdir, "storeref-show-id-git-count.txt")
  assert(fs.write(counter_file, ""))
  assert(fs.write(fs.join(wrapdir, "git"),
      ("#!/bin/sh\nprintf x >> '%s'\nexec '%s' \"$@\"\n"):format(counter_file, real_git)))
  assert(fs.set_mode(fs.join(wrapdir, "git"), fs.octal("755")))

  local target = make_item()
  assert(storewrite.save(s, target, "seed target", "## Change\ndo the thing\n"))

  --- Add `n` further open siblings, each with its own spec.
  local function seed_siblings(n: integer)
    for i = 1, n do
      local it = make_item()
      assert(storewrite.save(s, it, ("seed sibling %d"):format(i),
          ("## Change\nsibling change %d\n"):format(i)))
    end
  end

  --- How many `git` invocations one `gitshow.cmd_show` on `target`
  --- makes, with the wrapper ahead of the real binary on PATH.
  local function show_id_process_count(): integer
    assert(fs.write(counter_file, ""))
    local old_path = os.getenv("PATH") or ""
    assert(env.set("PATH", wrapdir .. ":" .. old_path, true))
    gitshow.cmd_show(s, target.id)
    assert(env.set("PATH", old_path, true))
    return #(fs.read(counter_file) or "")
  end

  -- Warm the cache once first, against `target` alone, so both
  -- measured calls below find a cache file already there — see the
  -- doc comment above.
  show_id_process_count()
  seed_siblings(3)
  local small = show_id_process_count()
  seed_siblings(12)
  local big = show_id_process_count()
  assert(small > 0, "the wrapper caught at least one invocation")
  assert(small == big,
    ("show <id>'s process count must not grow with sibling count: %d (4 "
      .. "items) vs %d (16 items)"):format(small, big))
end
