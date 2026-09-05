#!/usr/bin/env cosmic
-- The store's write half: `save`'s own contracts — the round trip
-- through `load`/`read_spec`, an unmoved sidecar on a nil spec, every
-- touched item landing as its own commit, and the no-op success — and
-- what `_work.publish` builds on it: a local-only store for the
-- save/load/spec mechanics, and a bare "remote" with clones for
-- publish — including the case the whole design exists for, where two
-- sessions race and the loser's push comes back rejected: the
-- mutation is dropped whole, the checkout re-syncs onto the winner's
-- state, and the refusal is LOST_RACE, so the re-run verb decides
-- against the merged board. `_work/store_test.tl` covers the read
-- half `save` here builds on: `open`/`resolve`/`load`/`list` and the
-- flagged-item tolerance.

local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local publish = require("_work.publish")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

local tmpdir = os.getenv("TEST_TMPDIR") or "/tmp"

-- Git reads a global (and system) config before it does anything, and
-- a config it cannot READ is fatal, not skipped — see
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

--- A fresh local-only state repo: `store.init_repo` (a bare git init
--- plus the `refs/heads/board/format` marker) — every item is a ref, so
--- there is nothing else to seed.
local function init_state_repo(name: string): string
  local root = fs.join(tmpdir, "storewrite-" .. name)
  assert(fs.remove_all(root))
  assert(fs.make_dirs(root))
  assert(store.init_repo(root))
  return root
end

--- A bare "remote" with nothing filed yet, plus n clones, each with
--- the mirror refspecs `store.init_repo` writes once it sees their
--- `origin`. The bare side finalizes objects by rename in ITS OWN
--- config: a file:// push spawns receive-pack with the pusher's `-c`
--- env scrubbed (git's local transport clears GIT_CONFIG_PARAMETERS),
--- and link-based finalization fails with EXDEV on the overlay mounts
--- CI containers run tests on.
local function init_shared(name: string, clones: integer): string, {string}
  local base = fs.join(tmpdir, "storewrite-shared-" .. name)
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

--- How many DISTINCT commits a checkout carries across every item and
--- ended ref — fixture arithmetic for "how many item writes has this
--- board seen", now that one mutation can be more than one commit
--- object (one per item it touches) held together only by the push.
local function commit_count(cwd: string): integer
  local names = check.must(child.run(
      {"git", "for-each-ref", "--format=%(refname)", "refs/heads/items", "refs/heads/ended"},
      {cwd = cwd}))
  assert(names.ok, "git for-each-ref failed: " .. names.stderr)
  local refnames: {string} = {}
  for line in names.stdout:gmatch("([^\n]+)") do
    refnames[#refnames + 1] = line
  end
  if #refnames == 0 then
    return 0
  end
  local argv: {string} = {"rev-list", "--count"}
  for _, r in ipairs(refnames) do
    argv[#argv + 1] = r
  end
  local r = check.must(child.run({"git", table.unpack(argv)}, {cwd = cwd}))
  assert(r.ok, "git rev-list failed: " .. r.stderr)
  return math.tointeger(tonumber((r.stdout:gsub("%s+$", "")))) or -1
end

local counter = 0

--- A fresh deterministic id; later calls sort later.
local function fresh_id(): string
  counter = counter + 1
  return check.must(ksuid.encode(1700000000 + counter, ("\0"):rep(16)))
end

local PARENT = check.must(ksuid.encode(1690000000, ("\1"):rep(16)))

--- A minimal valid workable item (under a parent the store never
--- checks — graph rules are flow's, exercised in flow_test). The
--- claim doubles as the mutable payload the round-trip tests edit.
local function make_item(claim?: string): item.Item
  return check.must(item.decode({
        id = fresh_id(), title = "an item", parent = PARENT,
        claim = claim or "",
      }))
end

local function test_save_load_spec_and_history()
  local root = init_state_repo("roundtrip")
  local s = check.must(store.open(root))
  local it = make_item("session-a")
  local short = it.id:sub(1, 8)
  assert(storewrite.save(s, it, "new " .. short, "## Change\nG1\n"))
  local loaded = check.must(store.load(s, it.id))
  assert(loaded.claim == "session-a", "claim: " .. loaded.claim)
  assert(store.read_spec(s, it.id) == "## Change\nG1\n", "spec sidecar")
  loaded.claim = "session-b"
  assert(storewrite.save(s, loaded, "take " .. short .. " by session-b"))
  assert(store.read_spec(s, it.id) == "## Change\nG1\n",
    "a nil spec leaves the sidecar alone")
  local events = check.must(publish.history(s, it.id))
  assert(#events == 2, "want 2 events, got " .. #events)
  assert(events[1].subject:find("by session%-b"), events[1].subject)
  local missing, merr = store.load(s, fresh_id())
  assert(missing == nil and merr:find("no item", 1, true), "missing item")
end

-- An item is two files worth of content — a `spec` mutation touches
-- only the sidecar half. A trail narrowed to the meta half would
-- leave every refinement out of it, which is how a spec that replaced
-- another spec went unseen.
local function test_history_covers_the_spec_sidecar()
  local root = init_state_repo("sidecar-history")
  local s = check.must(store.open(root))
  local it = make_item()
  local short = it.id:sub(1, 8)
  assert(storewrite.save(s, it, "new " .. short, "## Change\nG1\n"))
  assert(storewrite.save(s, it, "spec " .. short, "## Change\nG8\n"))
  local events = check.must(publish.history(s, it.id))
  assert(#events == 2, "want 2 events, got " .. #events)
  assert(events[1].subject == "spec " .. short,
    "the sidecar-only commit is in the trail: " .. events[1].subject)
end

-- Everything one mutation touches lands as its OWN commit, one per
-- item — the atomicity moved from the git commit object to the push
-- that lands them together; `save` alone (no publish) is what this
-- checks, so it is the local half of that guarantee.
local function test_save_writes_every_touched_item_as_its_own_commit()
  local root = init_state_repo("atomic")
  local s = check.must(store.open(root))
  local parent = make_item("session-a")
  assert(storewrite.save(s, parent, "new parent"))
  local before = commit_count(root)
  local kid = make_item()
  parent.claim = ""
  assert(storewrite.save(s, kid, "new kid", nil, {parent}))
  assert(commit_count(root) == before + 2,
    ("one commit per item touched: %d -> %d"):format(before, commit_count(root)))
  assert(check.must(store.load(s, parent.id)).claim == "",
    "the unlocked parent is in that commit")
  assert(check.must(store.load(s, kid.id)).id == kid.id, "so is the child")
end

-- A mutation that changes nothing is the state the caller asked for
-- already holding: `save` SUCCEEDS, no commit made, `is_noop`-testable
-- on the message it carries — not a refusal surfacing git's exit code
-- with the explanation on a stream nobody read.
local function test_save_succeeds_on_a_no_op()
  local root = init_state_repo("noop")
  local s = check.must(store.open(root))
  local it = make_item()
  assert(storewrite.save(s, it, "new item"))
  local before = commit_count(root)
  local ok, err = storewrite.save(s, it, "take it nowhere")
  assert(ok, "an unchanged item is still a success: " .. tostring(err))
  assert(store.is_noop(err), "is_noop recognizes it: " .. err)
  assert(err:find("nothing to record", 1, true), "got: " .. err)
  assert(commit_count(root) == before, "and no commit is made")
end

-- An item's own `order` — the ranked child ids it carries — is an
-- ordinary field like any other: it round-trips through `save`/`load`
-- exactly as `claim` does above.
local function test_an_items_order_round_trips_through_save_and_load()
  local root = init_state_repo("item-order-roundtrip")
  local s = check.must(store.open(root))
  local parent = make_item()
  local kid1 = make_item()
  local kid2 = make_item()
  assert(storewrite.save(s, parent, "new parent", nil, {kid1, kid2}))
  parent.order = {kid1.id, kid2.id}
  assert(storewrite.save(s, parent, "rank the children"))
  local loaded = check.must(store.load(s, parent.id))
  assert(#loaded.order == 2 and loaded.order[1] == kid1.id and loaded.order[2] == kid2.id,
    "order round-trips in rank order: " .. table.concat(loaded.order, ","))
end

-- The board's own root ranking has no item behind it at all: it lives
-- on `refs/heads/board/order` alone, written by `save_root_order` (no
-- verb calls it yet) and read back by `store.list`/`store.root_order`
-- the same way `store.list` already surfaces `refs/heads/board/seq`.
local function test_the_board_root_order_round_trips_through_save_and_list()
  local root = init_state_repo("root-order-roundtrip")
  local s = check.must(store.open(root))
  local r1 = make_item()
  local r2 = make_item()
  r1.parent, r2.parent = "", ""
  assert(storewrite.save(s, r1, "new r1", nil, {r2}))
  assert(#store.root_order(s) == 0, "no root ranking has been written yet")
  assert(storewrite.save_root_order(s, {r1.id, r2.id}, "rank the roots"))
  assert(#store.root_order(s) == 2 and store.root_order(s)[1] == r1.id,
    "save_root_order updates the store's own observed ranking")

  -- A fresh store handle re-reads it straight from git, through `list`.
  local s2 = check.must(store.open(root))
  check.must(store.list(s2))
  local got = store.root_order(s2)
  assert(#got == 2 and got[1] == r1.id and got[2] == r2.id,
    "the board's root ranking round-trips: " .. table.concat(got, ","))
end

-- Writing the SAME ranking again is a no-op, exactly like an unchanged
-- item save — `is_noop`-testable, and no new commit on the ref.
local function test_writing_the_same_root_order_again_is_a_no_op()
  local root = init_state_repo("root-order-noop")
  local s = check.must(store.open(root))
  local r1 = make_item()
  r1.parent = ""
  assert(storewrite.save(s, r1, "new r1"))
  assert(storewrite.save_root_order(s, {r1.id}, "rank the roots"))
  local ok, err = storewrite.save_root_order(s, {r1.id}, "rank the roots again")
  assert(ok, "an unchanged ranking is still a success: " .. tostring(err))
  assert(store.is_noop(err), "is_noop recognizes it: " .. err)
end

-- `refs/heads/board/order` rides the same `+refs/heads/board/*:...`
-- mirror refspec `refs/heads/board/seq`/`format` already fetch and push
-- through — confirmed here rather than assumed: a root ranking
-- published from one clone reaches a `sync` on another, with no code
-- of its own in `_work.publish`.
local function test_the_board_root_order_publishes_and_syncs()
  local bare, clones = init_shared("root-order-sync", 2)
  assert(bare)
  local a = check.must(store.open(clones[1]))
  local r1 = make_item()
  r1.parent = ""
  assert(storewrite.save(a, r1, "new r1"))
  assert(publish.publish(a))
  assert(storewrite.save_root_order(a, {r1.id}, "rank the roots"))
  assert(publish.publish(a))

  local b = check.must(store.open(clones[2]))
  assert(publish.sync(b))
  check.must(store.list(b))
  local got = store.root_order(b)
  assert(#got == 1 and got[1] == r1.id,
    "the root ranking reaches the second clone: " .. table.concat(got, ","))
end

local function test_publish_fast_forward()
  local bare, clones = init_shared("ff", 2)
  assert(bare)
  local a = check.must(store.open(clones[1]))
  local it = make_item("session-a")
  assert(storewrite.save(a, it, "new item"))
  assert(publish.publish(a))
  local b = check.must(store.open(clones[2]))
  assert(publish.sync(b))
  local got = check.must(store.load(b, it.id))
  assert(got.claim == "session-a",
    "the published item reaches the second clone")
end

-- The bounded-mutation seq lease (a take of new work, racing another
-- across two DIFFERENT items) has its own test: `_work/storeref_test.tl`.

-- Two sessions edit the SAME item. The loser's commit is dropped
-- before anything downstream could see it, so there is no half-landed
-- state for a later verb to trip on: the refusal is the same
-- LOST_RACE every lost race gets, and the re-run verb — loading the
-- winner's state — is what discovers the semantic collision (a claim
-- guard, a phase gate) and names it.
local function test_publish_drops_a_lost_edit_of_the_same_item()
  local _, clones = init_shared("conflict", 2)
  local a = check.must(store.open(clones[1]))
  local contested = make_item()
  assert(storewrite.save(a, contested, "new contested"))
  assert(publish.publish(a))
  local b = check.must(store.open(clones[2]))
  assert(publish.sync(b))

  local ia = check.must(store.load(a, contested.id))
  ia.claim = "session-a"
  assert(storewrite.save(a, ia, "take contested by session-a"))
  assert(publish.publish(a))

  local ib = check.must(store.load(b, contested.id))
  ib.claim = "session-b"
  ib.pr = 7
  assert(storewrite.save(b, ib, "take contested by session-b"))
  local ok, err = publish.publish(b)
  assert(not ok, "the losing edit of the same item must be refused")
  assert(err == store.LOST_RACE, "got: " .. err)

  local after = check.must(store.load(b, contested.id))
  assert(after.claim == "session-a" and after.pr == 0,
    "the loser's checkout holds the winner's state: " .. after.claim)
  assert(store.list(b), "the board stays readable after the refusal")
end

-- `sync` never merges — it is exactly `fetch --prune` against the
-- mirror refspecs — so a checkout's own unpublished commit on a ref
-- the remote also moved is not a conflict to refuse: the local ref is
-- simply force-reset to the remote's value, same as any other lost
-- race's recovery. There is no working tree left to carry conflict
-- markers, and nothing here is ever destructive beyond that reset.
local function test_sync_overwrites_an_unpublished_local_commit()
  local _, clones = init_shared("sync-overwrite", 2)
  local a = check.must(store.open(clones[1]))
  local contested = make_item()
  assert(storewrite.save(a, contested, "new contested"))
  assert(publish.publish(a))
  local b = check.must(store.open(clones[2]))
  assert(publish.sync(b))

  local ia = check.must(store.load(a, contested.id))
  ia.claim = "session-a"
  assert(storewrite.save(a, ia, "take contested by session-a"))
  assert(publish.publish(a))

  -- b's own commit, never published — the hand-edit-workaround shape.
  local ib = check.must(store.load(b, contested.id))
  ib.claim = "session-b"
  ib.pr = 7
  assert(storewrite.save(b, ib, "hand-edit contested for session-b"))
  assert(publish.sync(b), "sync always succeeds — it never merges")
  assert(check.must(store.load(b, contested.id)).claim == "session-a",
    "the local unpublished commit is overwritten by the remote's")
end

-- The atomic multi-ref publish (a save touching two items, one
-- contested) has its own test: `_work/storeref_test.tl`.

-- A rejection with the remote unmoved is the remote's policy — a
-- pre-receive hook, a read-only token — not a race. The destructive
-- branch must not run: the commit stays local, the refusal does not
-- claim a race, and the remote's own words reach the caller instead
-- of being swallowed. This is also the one place "rejected" alone
-- must NOT be read as a lost race: git's hook-decline text is
-- "[remote rejected]", a different marker from the lease failure's
-- "[rejected] ... (stale info)".
local function test_publish_keeps_the_mutation_on_a_policy_rejection()
  local bare, clones = init_shared("policy", 1)
  local a = check.must(store.open(clones[1]))
  local hook = fs.join(bare, "hooks", "pre-receive")
  assert(fs.write(hook,
      "#!/bin/sh\necho 'policy: board is read-only' >&2\nexit 1\n"))
  assert(fs.set_mode(hook, fs.octal("755")))

  local it = make_item("session-a")
  assert(storewrite.save(a, it, "new under policy"))
  local before = commit_count(clones[1])
  local ok, err = publish.publish(a)
  assert(not ok, "the rejected push must refuse")
  assert(err ~= store.LOST_RACE and not err:find("lost the push race", 1, true),
    "no race is claimed when the remote never moved: " .. err)
  assert(err:find("policy: board is read-only", 1, true),
    "the remote's own words reach the caller: " .. err)
  assert(err:find("still local", 1, true), "and the refusal says the "
    .. "commit survives: " .. err)
  assert(commit_count(clones[1]) == before,
    "the mutation was not destroyed")
  assert(check.must(store.load(a, it.id)).claim == "session-a",
    "and still reads back")
end
