#!/usr/bin/env cosmic
-- The store is exercised against scratch git repositories this file
-- builds itself: a local-only store for the save/load/spec mechanics,
-- and a bare "remote" with clones for publish — including the case
-- the whole design exists for, where two sessions race and the loser's
-- push comes back rejected: the mutation is dropped whole, the
-- checkout re-syncs onto the winner's state, and the refusal is
-- LOST_RACE, so the re-run verb decides against the merged board.

local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local gitobj = require("_work.gitobj")
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local ksuid = require("_work.ksuid")
local publish = require("_work.publish")
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
  local root = fs.join(tmpdir, "store-" .. name)
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
  local base = fs.join(tmpdir, "shared-" .. name)
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

--- Write an item straight to its ref, past `stage`'s validator — a
--- pre-refusal writer's shape, or a hand edit from an older board.
--- Works for a brand-new id (no lease yet) as much as an existing one.
--- @param s store.Store The store
--- @param bad item.Item An item whose `item.problems` may be non-empty
local function write_unchecked(s: store.Store, bad: item.Item)
  -- `true`: the tree must actually exist for `commit_tree` below to
  -- build on it.
  local tree_sha = check.must(itemtree.build_tree(s.root, bad, store.read_spec(s, bad.id), true))
  local ref = s.leased_ref[bad.id] or ("refs/heads/items/" .. bad.id)
  local parent_sha = s.leased_sha[bad.id] or refs.ZERO_SHA
  local parents: {string} = {}
  if parent_sha ~= refs.ZERO_SHA then
    parents = {parent_sha}
  end
  local commit_sha = check.must(gitobj.commit_tree(s.root, {
        tree = tree_sha, parents = parents, message = "hand-edit",
        author_name = "test", author_email = "test@example.com",
        committer_name = "test", committer_email = "test@example.com",
      }))
  assert(refs.update_ref(s.root, ref, commit_sha, parent_sha))
end

-- `store.init_repo`/`open` have their own tests: `_work/storeinit_test.tl`.

local function test_save_load_spec_and_history()
  local root = init_state_repo("roundtrip")
  local s = check.must(store.open(root))
  local it = make_item("session-a")
  local short = it.id:sub(1, 8)
  assert(store.save(s, it, "new " .. short, "## Change\nG1\n"))
  local loaded = check.must(store.load(s, it.id))
  assert(loaded.claim == "session-a", "claim: " .. loaded.claim)
  assert(store.read_spec(s, it.id) == "## Change\nG1\n", "spec sidecar")
  loaded.claim = "session-b"
  assert(store.save(s, loaded, "take " .. short .. " by session-b"))
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
  assert(store.save(s, it, "new " .. short, "## Change\nG1\n"))
  assert(store.save(s, it, "spec " .. short, "## Change\nG8\n"))
  local events = check.must(publish.history(s, it.id))
  assert(#events == 2, "want 2 events, got " .. #events)
  assert(events[1].subject == "spec " .. short,
    "the sidecar-only commit is in the trail: " .. events[1].subject)
end

local function test_resolve_prefixes()
  local root = init_state_repo("resolve")
  local s = check.must(store.open(root))
  local a = make_item()
  local b = make_item()
  assert(store.save(s, a, "new a"))
  assert(store.save(s, b, "new b"))
  assert(check.must(store.resolve(s, a.id)) == a.id, "full ids resolve")
  assert(check.must(store.resolve(s, a.id:sub(1, 26))) == a.id,
    "a unique prefix resolves")
  -- The deterministic ids share all but their trailing bytes, so the
  -- short common prefix is ambiguous by construction.
  local amb, aerr = store.resolve(s, a.id:sub(1, 4))
  assert(amb == nil and aerr:find("ambiguous", 1, true), "ambiguity is named")
  local none, nerr = store.resolve(s, "zzzz")
  assert(none == nil and nerr:find("no item", 1, true), "a miss is named")
end

-- `resolve`'s own one-shot lease is what lets the very next `load` of
-- the resolved id skip repeating this prefix's for-each-ref —
-- `_work.gitboard`'s handle route gets the symmetric guard in
-- `_work/gitboard_test.tl`; this is the prefix half.
local function test_resolve_leases_the_load_that_follows_a_prefix()
  local root = init_state_repo("resolve-leases-load")
  local s = check.must(store.open(root))
  local a = make_item()
  assert(store.save(s, a, "new a"))
  local resolved = check.must(store.resolve(s, a.id:sub(1, 26)))
  assert(resolved == a.id, "the prefix resolves")

  local exact_pattern = {"refs/heads/items/" .. a.id, "refs/heads/ended/" .. a.id}
  local exact_calls = 0
  local real_for_each_ref = refs.for_each_ref
  refs.for_each_ref = function(croot: string, patterns: {string}):
    {refs.RefEntry} | nil, string
    if #patterns == 2 and patterns[1] == exact_pattern[1]
    and patterns[2] == exact_pattern[2] then
      exact_calls = exact_calls + 1
    end
    return real_for_each_ref(croot, patterns)
  end
  local ok, loaded = pcall(store.load, s, resolved)
  refs.for_each_ref = real_for_each_ref
  if not ok then
    error(loaded, 0)
  end
  assert(loaded ~= nil, "the load should succeed")
  assert(exact_calls == 0, "a resolved prefix's own load must not repeat "
    .. "the exact-ref for-each-ref an unleased load would run: " .. exact_calls)
end

-- Everything one mutation touches lands as its OWN commit, one per
-- item — the atomicity moved from the git commit object to the push
-- that lands them together; `save` alone (no publish) is what this
-- checks, so it is the local half of that guarantee.
local function test_save_writes_every_touched_item_as_its_own_commit()
  local root = init_state_repo("atomic")
  local s = check.must(store.open(root))
  local parent = make_item("session-a")
  assert(store.save(s, parent, "new parent"))
  local before = commit_count(root)
  local kid = make_item()
  parent.claim = ""
  assert(store.save(s, kid, "new kid", nil, {parent}))
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
  assert(store.save(s, it, "new item"))
  local before = commit_count(root)
  local ok, err = store.save(s, it, "take it nowhere")
  assert(ok, "an unchanged item is still a success: " .. tostring(err))
  assert(store.is_noop(err), "is_noop recognizes it: " .. err)
  assert(err:find("nothing to record", 1, true), "got: " .. err)
  assert(commit_count(root) == before, "and no commit is made")
end

-- An ordinary success and a terminal failure are never mistaken for
-- the no-op outcome.
local function test_is_noop_is_specific()
  assert(not store.is_noop(""), "an empty message is not a no-op")
  assert(not store.is_noop("git commit failed: disk full"),
    "an unrelated failure is not a no-op")
end

-- The bricking incident, restated for the ref layout: a `meta` blob is
-- `key: value` LINES, so a value that itself held a newline (the
-- original incident's multiline title) can no longer even reach
-- storage looking multiline — the line format is what refuses it now,
-- before `item.problems` ever gets a say. The tolerance this pins is
-- the same one either way: a content-invalid item — here, a ROOT
-- hand-edited to carry a claim, a shape only `write_unchecked` can
-- produce — must not abort `list`; the rest still reads, the bad one
-- comes back flagged, not dropped, and write-refusal is unchanged.
local function test_list_tolerates_a_flagged_item_but_stage_still_refuses()
  local root = init_state_repo("list-tolerant")
  local s = check.must(store.open(root))
  local good = make_item()
  assert(store.save(s, good, "new good"))
  local bad = check.must(item.decode({id = fresh_id(), title = "a root"}))
  bad.claim = "session-x"
  local ok, serr = store.stage(s, bad)
  assert(not ok and serr:find("belong to worked items, not roots", 1, true) ~= nil,
    "stage refuses the same shape: " .. tostring(serr))
  write_unchecked(s, bad)
  local all = check.must(store.list(s))
  assert(#all == 2, "the bad record is included, not dropped: got " .. #all)
  for _, it in ipairs(all) do
    assert(item.is_flagged(it) == (it.id == bad.id), "flagged iff bad")
  end
  local summary = store.flagged_summary(all)
  assert(summary:find(bad.id:sub(1, 8), 1, true) and
    summary:find("belong to worked items, not roots", 1, true), "summary: " .. summary)
end

-- Repairability falls out: `set` loads through this same tolerant
-- decode, so clearing the stray claim and saving clears the flag.
local function test_a_flagged_item_is_repairable_through_the_tolerant_decode()
  local root = init_state_repo("repair")
  local s = check.must(store.open(root))
  local seed = check.must(item.decode({id = fresh_id(), title = "a root"}))
  seed.claim = "session-x"
  write_unchecked(s, seed)
  local loaded = check.must(store.load(s, seed.id))
  assert(item.is_flagged(loaded), "the bad record still loads, flagged")
  loaded.claim = ""
  assert(store.save(s, loaded, "set " .. seed.id:sub(1, 8) .. " claim"),
    "the repair commits: problems(it) is now empty")
  local fixed = check.must(store.load(s, seed.id))
  assert(not item.is_flagged(fixed) and fixed.claim == "", "clean")
  assert(store.flagged_summary(check.must(store.list(s))) == "",
    "listing recovers: nothing left flagged")
end

local function test_publish_fast_forward()
  local bare, clones = init_shared("ff", 2)
  assert(bare)
  local a = check.must(store.open(clones[1]))
  local it = make_item("session-a")
  assert(store.save(a, it, "new item"))
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
  assert(store.save(a, contested, "new contested"))
  assert(publish.publish(a))
  local b = check.must(store.open(clones[2]))
  assert(publish.sync(b))

  local ia = check.must(store.load(a, contested.id))
  ia.claim = "session-a"
  assert(store.save(a, ia, "take contested by session-a"))
  assert(publish.publish(a))

  local ib = check.must(store.load(b, contested.id))
  ib.claim = "session-b"
  ib.pr = 7
  assert(store.save(b, ib, "take contested by session-b"))
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
  assert(store.save(a, contested, "new contested"))
  assert(publish.publish(a))
  local b = check.must(store.open(clones[2]))
  assert(publish.sync(b))

  local ia = check.must(store.load(a, contested.id))
  ia.claim = "session-a"
  assert(store.save(a, ia, "take contested by session-a"))
  assert(publish.publish(a))

  -- b's own commit, never published — the hand-edit-workaround shape.
  local ib = check.must(store.load(b, contested.id))
  ib.claim = "session-b"
  ib.pr = 7
  assert(store.save(b, ib, "hand-edit contested for session-b"))
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
  assert(store.save(a, it, "new under policy"))
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
