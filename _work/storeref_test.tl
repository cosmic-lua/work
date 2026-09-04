#!/usr/bin/env cosmic
-- Properties specific to the ref layout itself, as opposed to
-- `_work/store_test.tl`'s save/load/publish mechanics: the bounded
-- mutation seq lease, atomicity across every ref one save touches,
-- the ended-item ref move, and `list`'s fixed process count. Its own
-- file so `store_test.tl` stays under the line cap.

local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local flow = require("_work.flow")
local fs = require("cosmic.fs")
local gitshow = require("_work.gitshow")
local gitview = require("_work.gitview")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local publish = require("_work.publish")
local store = require("_work.store")

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

--- A fresh local-only state repo, with its `refs/heads/board/format` marker.
local function init_state_repo(name: string): string
  local root = fs.join(tmpdir, "storeref-" .. name)
  assert(fs.remove_all(root))
  assert(fs.make_dirs(root))
  assert(store.init_repo(root))
  return root
end

--- A bare "remote" with nothing filed yet, plus n clones.
local function init_shared(name: string, clones: integer): string, {string}
  local base = fs.join(tmpdir, "storeref-shared-" .. name)
  assert(fs.remove_all(base))
  assert(fs.make_dirs(base))
  local bare = fs.join(base, "remote.git")
  git(base, {"init", "-q", "--bare", bare})
  git(bare, {"config", "core.createObject", "rename"})
  local out: {string} = {}
  for i = 1, clones do
    local dir = fs.join(base, ("clone%d"):format(i))
    git(base, {"clone", "-q", bare, dir})
    git(dir, {"config", "core.createObject", "rename"})
    assert(store.init_repo(dir))
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

--- A minimal valid workable item.
local function make_item(claim?: string): item.Item
  return check.must(item.decode({
        id = fresh_id(), title = "an item", parent = PARENT,
        claim = claim or "",
      }))
end

-- Two sessions race the last doing slot on TWO DIFFERENT items. Under
-- the ref layout that alone is no longer a collision — unrelated
-- items live on unrelated refs, and an unbounded take of one never
-- contends with a take of the other. What still makes them race is
-- `refs/heads/board/seq`: `take`ing NEW work is a BOUNDED mutation (its gate
-- read the whole board first, to judge the doing bound), so its save
-- ALSO advances and leases seq — the one shared ref that puts two
-- otherwise-unrelated takes back in each other's way, exactly the way
-- the real doing bound needs them to be. The first push wins; the
-- loser's publish drops its commit whole, re-syncs, and refuses with
-- LOST_RACE — the verb re-runs against the merged board, whose doing
-- bound refuses the take, which is the compare-and-swap a lagged
-- index cannot give.
local function test_bounded_seq_lease_stops_two_new_takes_from_both_landing()
  local _, clones = init_shared("cas", 2)
  local a = check.must(store.open(clones[1]))
  for i = 1, flow.DOING_LIMIT - 1 do
    assert(store.save(a, make_item(("busy-%d"):format(i)),
        ("busy %d"):format(i)))
  end
  local mine = make_item()
  local yours = make_item()
  assert(store.save(a, mine, "new mine"))
  assert(store.save(a, yours, "new yours"))
  assert(publish.publish(a))
  local b = check.must(store.open(clones[2]))
  assert(publish.sync(b))

  -- Both sides read the whole board (as `flow.doing_refusal`'s own
  -- caller does) before deciding to take — this is what a bounded
  -- gate's precondition looks like, and what makes `set_bounded`
  -- honest here rather than a bare flag with nothing behind it.
  assert(store.list(a))
  local ia = check.must(store.load(a, mine.id))
  ia.claim = "session-a"
  store.set_bounded(a, true)
  assert(store.save(a, ia, "take mine by session-a"))
  assert(publish.publish(a))

  assert(store.list(b))
  local ib = check.must(store.load(b, yours.id))
  ib.claim = "session-b"
  store.set_bounded(b, true)
  assert(store.save(b, ib, "take yours by session-b"))
  local ok, err = publish.publish(b)
  assert(not ok, "the losing take must be refused")
  assert(err == store.LOST_RACE, "got: " .. err)
  local back = check.must(store.load(b, yours.id))
  assert(back.claim == "", "the dropped mutation is undone whole")
  local winner = check.must(store.load(b, mine.id))
  assert(winner.claim == "session-a",
    "the winning take is visible after the sync")
  assert(flow.doing_refusal(check.must(store.list(b))) ~= nil,
    "doing holds exactly its bound — the re-run verb's own gate now "
    .. "refuses this take")
end

-- The atomicity the push provides, not the commit object: a save that
-- touches two items (a decomposition's child and the parent it
-- de-phases) makes two commits, and when the remote has moved under
-- ONE of them, the WHOLE push is refused — neither ref lands, not
-- just the contested one.
local function test_publish_is_atomic_across_every_ref_a_save_touched()
  local _, clones = init_shared("atomic-multiref", 2)
  local a = check.must(store.open(clones[1]))
  local parent = make_item("session-a")
  assert(store.save(a, parent, "new parent"))
  assert(publish.publish(a))
  local b = check.must(store.open(clones[2]))
  assert(publish.sync(b))

  -- a moves the parent forward, out from under b — a distinct,
  -- checkable change (the title), so the assertion below cannot be
  -- satisfied by coincidence.
  local pa = check.must(store.load(a, parent.id))
  pa.title = "retitled by a"
  assert(store.save(a, pa, "set parent title"))
  assert(publish.publish(a))

  -- b, still on the stale parent, writes a new child AND de-phases
  -- the parent in the same mutation — two commits, one save.
  local pb = check.must(store.load(b, parent.id))
  local kid = make_item()
  pb.claim = ""
  assert(store.save(b, kid, "new kid", nil, {pb}))
  local ok, err = publish.publish(b)
  assert(not ok and err == store.LOST_RACE, "got: " .. tostring(err))
  assert(store.load(b, kid.id) == nil,
    "the brand-new child never lands without its parent's commit")
  local after = check.must(store.load(b, parent.id))
  assert(after.title == "retitled by a" and after.claim == "session-a",
    "the parent shows the winner's own state, not b's dropped claim: "
    .. after.title .. " / " .. after.claim)
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

-- A resolution MOVES the ref: `refs/heads/items/<id>` stops existing and
-- `refs/heads/ended/<id>` starts, in one local transaction — never both at
-- once, never neither.
local function test_resolution_moves_the_ref_from_items_to_ended()
  local root = init_state_repo("ended-move")
  local s = check.must(store.open(root))
  local it = make_item()
  assert(store.save(s, it, "new item"))
  local before = item_refnames(root)
  local found_open = false
  for _, r in ipairs(before) do
    if r == "refs/heads/items/" .. it.id then
      found_open = true
    end
  end
  assert(found_open, "the item starts on refs/heads/items")

  it.resolution = "completed"
  assert(store.save(s, it, "done " .. it.id:sub(1, 8)))
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
  assert(not still_open, "refs/heads/items no longer names it")
  assert(now_ended, "refs/heads/ended now does")
  local loaded = check.must(store.load(s, it.id))
  assert(loaded.resolution == "completed", "load still finds it, resolved")
  -- The move is one local transaction: `_work.refs.move_to_ended`'s
  -- `update-ref --stdin`, not two independent updates a crash could
  -- catch between.
  local events = check.must(publish.history(s, it.id))
  assert(#events == 2, "the ref's own history still holds both commits: "
    .. #events)
end

-- `list` runs a FIXED number of git processes regardless of board
-- size: one `for-each-ref`, one `cat-file --batch` for every item's
-- meta/held/edges, one more for every edge kind's own subtree
-- content, and one more for every content blob (a blocked_by or
-- other-kind reason) — never one process per item. Counted by racing
-- `git` itself: a
-- counting wrapper ahead of the real binary on PATH, so every
-- invocation `_work.refs`/`_work.gitobj` make is caught, not just the
-- ones this test happens to know the argv for.
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
      assert(store.save(s, it, ("seed %d"):format(i)))
      ids[#ids + 1] = it.id
    end
    for i = 2, n do
      local it = check.must(store.load(s, ids[i]))
      it.blocked_by = {ids[1]}
      it.block_reason = {[ids[1]] = "seeding order"}
      assert(store.save(s, it, "block"))
    end
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
  assert(small <= 4, ("at most 4 processes: got %d"):format(small))
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
      assert(store.save(s, it, ("seed %d"):format(i),
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
  -- `store.save` directly, bypassing the incremental hooks
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
--- as the number of siblings around it grows.
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
  assert(store.save(s, target, "seed target", "## Change\ndo the thing\n"))

  --- Add `n` further open siblings, each with its own spec.
  local function seed_siblings(n: integer)
    for i = 1, n do
      local it = make_item()
      assert(store.save(s, it, ("seed sibling %d"):format(i),
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

  seed_siblings(3)
  local small = show_id_process_count()
  seed_siblings(12)
  local big = show_id_process_count()
  assert(small > 0, "the wrapper caught at least one invocation")
  assert(small == big,
    ("show <id>'s process count must not grow with sibling count: %d (4 "
      .. "items) vs %d (16 items)"):format(small, big))
end
