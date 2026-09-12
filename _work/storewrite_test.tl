#!/usr/bin/env cosmic
-- The store's write half: `save`'s own contracts — the round trip
-- through `load`/`read_spec`, an unmoved sidecar on a nil spec, every
-- touched item landing as its own commit, and the no-op success — and
-- what `_work.publish` builds on it: a local-only store for the
-- save/load/spec mechanics, and a bare "remote" with clones for
-- publish — including the case the whole design exists for, where two
-- sessions race and the loser's leased push comes back rejected: the
-- prepared successor remains reachable, and an explicit caller fetch
-- lets refresh classify it against the winner. `_work/store_test.tl` covers the read
-- half `save` here builds on: `open`/`resolve`/`load`/`list` and the
-- flagged-item tolerance.

local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local publish = require("_work.publish")
local prepared = require("_work.prepared")
local refs = require("_work.refs")
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

-- `store.init_repo` runs a handful of git processes (init, the board
-- commit) that never vary between calls — build the result once per
-- process and copy it, instead of paying that cost on every case.
local state_template: string | nil = nil

--- A fresh local-only state repo: `store.init_repo` (a bare git init
--- plus the `refs/heads/board/format` marker) — every item is a ref, so
--- there is nothing else to seed.
local function init_state_repo(name: string): string
  if state_template == nil then
    state_template = fs.join(tmpdir, "storewrite-template")
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
  local root = fs.join(tmpdir, "storewrite-" .. name)
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
  local base = fs.join(tmpdir, "storewrite-shared-template-" .. clones)
  assert(fs.remove_all(base))
  assert(fs.make_dirs(base))
  local bare = fs.join(base, "remote.git")
  git(base, {"init", "-q", "--bare", bare})
  git(bare, {"config", "core.createObject", "rename"})
  -- Every push below runs server-side `git gc --auto --quiet` via
  -- receive-pack unless this is set (confirmed via `GIT_TRACE=1`) — the
  -- same transient-lock race a porcelain commit's `maintenance.auto`
  -- causes, just the legacy `gc.auto` mechanism, from the receiving end.
  git(bare, {"config", "receive.autogc", "false"})
  for i = 1, clones do
    local dir = fs.join(base, ("clone%d"):format(i))
    git(base, {"clone", "-q", bare, dir})
    git(dir, {"config", "core.createObject", "rename"})
    git(dir, {"config", "maintenance.auto", "false"})
    if i > 1 then
      -- The first clone's own `init_repo` mints the board (and
      -- best-effort pushes it); fetch it down before this clone's own
      -- `init_repo` runs, so it finds that board already there
      -- instead of minting a second one.
      assert(refs.ensure_refspecs(dir))
      assert(refs.fetch_prune(dir))
    end
    assert(store.init_repo(dir))
    if i == 1 then
      -- Initialization is local-only. The fixture plays the caller:
      -- publish the initial format and board refs, then fetch their
      -- canonical remote-tracking names before opening the store.
      git(dir, {"push", "-q", "--atomic", "origin",
          "refs/heads/items/*:refs/heads/items/*",
          "refs/heads/board/*:refs/heads/board/*"})
      assert(refs.fetch_prune(dir))
    end
  end
  return base
end

--- A bare "remote" with nothing filed yet, plus n clones, each with
--- the mirror refspecs `store.init_repo` writes once it sees their
--- `origin`. The bare side finalizes objects by rename in ITS OWN
--- config: a file:// push spawns receive-pack with the pusher's `-c`
--- env scrubbed (git's local transport clears GIT_CONFIG_PARAMETERS),
--- and link-based finalization fails with EXDEV on the overlay mounts
--- CI containers run tests on.
local function init_shared(name: string, clones: integer): string, {string}
  if shared_templates[clones] == nil then
    shared_templates[clones] = build_shared_template(clones)
  end
  local base = fs.join(tmpdir, "storewrite-shared-" .. name)
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
--- checks — graph rules are flow's, exercised in flow_test). Claims
--- are projected from format-4 claim batches, so store-layer tests
--- mutate ordinary persisted fields instead.
local function make_item(title?: string): item.Item
  return check.must(item.decode({
        id = fresh_id(), title = title or "an item", parent = PARENT,
      }))
end

local function test_save_load_spec_and_history()
  local root = init_state_repo("roundtrip")
  local s = check.must(store.open(root))
  local it = make_item("first title")
  local short = it.id:sub(1, 8)
  assert(storewrite.save(s, it, "new " .. short, "## Change\nG1\n"))
  local loaded = check.must(store.load(s, it.id))
  assert(loaded.title == "first title", "title: " .. loaded.title)
  assert(store.read_spec(s, it.id) == "## Change\nG1\n", "spec sidecar")
  loaded.title = "second title"
  assert(storewrite.save(s, loaded, "retitle " .. short .. " by session-b"))
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
  local parent = make_item("claimed-looking title")
  assert(storewrite.save(s, parent, "new parent"))
  local before = commit_count(root)
  local kid = make_item()
  parent.title = "updated parent"
  assert(storewrite.save(s, kid, "new kid", nil, {parent}))
  assert(commit_count(root) == before + 2,
    ("one commit per item touched: %d -> %d"):format(before, commit_count(root)))
  assert(check.must(store.load(s, parent.id)).title == "updated parent",
    "the updated parent is in that commit")
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

-- The board's own outcome ranking is not a separate mechanism at all:
-- it is the board item's own `order` field, an ordinary `save` like
-- any other item's — covered by `_work/gitrank_test.tl`'s
-- `test_rank_among_outcomes_writes_and_reads_back` and
-- `test_an_outcome_rank_survives_a_rebase`, which exercise it through
-- the real `rank` verb rather than a bespoke write path here.

local function test_publish_fast_forward()
  local bare, clones = init_shared("ff", 2)
  assert(bare)
  local a = check.must(store.open(clones[1]))
  local it = make_item("session-a title")
  assert(storewrite.save(a, it, "new item"))
  assert(publish.publish(a, true))
  local b = check.must(store.open(clones[2]))
  assert(publish.sync(b, true))
  local got = check.must(store.load(b, it.id))
  assert(got.title == "session-a title",
    "the published item reaches the second clone")
end

-- The bounded-mutation seq lease (a take of new work, racing another
-- across two DIFFERENT items) has its own test: `_work/storeref_test.tl`.

-- Two sessions edit the SAME item. The loser's prepared successor
-- remains intact after its leased push is refused; once the caller
-- fetches, refresh classifies it as a lost race and canonical reads
-- expose the winner.
local function test_publish_drops_a_lost_edit_of_the_same_item()
  local _, clones = init_shared("conflict", 2)
  local a = check.must(store.open(clones[1]))
  local contested = make_item()
  assert(storewrite.save(a, contested, "new contested"))
  assert(publish.publish(a, true))
  local b = check.must(store.open(clones[2]))
  assert(publish.sync(b, true))

  local ia = check.must(store.load(a, contested.id))
  ia.title = "winner title"
  assert(storewrite.save(a, ia, "retitle contested by session-a"))
  assert(publish.publish(a, true))

  local ib = check.must(store.load(b, contested.id))
  ib.pr = 7
  assert(storewrite.save(b, ib, "set contested pr by session-b"))
  local ok = publish.publish(b, true)
  assert(not ok, "the losing edit of the same item must be refused")
  local synced, err = publish.sync(b, true)
  assert(not synced and err:find("lost their ref lease", 1, true) ~= nil,
    "refresh classifies the staged successor after fetching: " .. err)

  local after = check.must(store.load(b, contested.id))
  assert(after.title == "winner title" and after.pr == 0,
    "the loser's checkout holds the winner's state: " .. after.title)
  assert(store.list(b), "the board stays readable after the refusal")
end

-- Explicit refresh fetches only remote-tracking refs. A local
-- unpublished successor can remain in Git, but canonical board reads
-- ignore it and expose the fetched remote value.
local function test_sync_ignores_an_unpublished_local_commit()
  local _, clones = init_shared("sync-overwrite", 2)
  local a = check.must(store.open(clones[1]))
  local contested = make_item()
  assert(storewrite.save(a, contested, "new contested"))
  assert(publish.publish(a, true))
  local b = check.must(store.open(clones[2]))
  assert(publish.sync(b, true))

  local ia = check.must(store.load(a, contested.id))
  ia.title = "winner title"
  assert(storewrite.save(a, ia, "retitle contested by session-a"))
  assert(publish.publish(a, true))

  -- b's own commit, never published — the hand-edit-workaround shape.
  local ib = check.must(store.load(b, contested.id))
  ib.pr = 7
  assert(storewrite.save(b, ib, "hand-edit contested for session-b"))
  assert(publish.sync(b, true), "explicit refresh fetches but never merges")
  assert(check.must(store.load(b, contested.id)).title == "winner title",
    "the local unpublished commit is overwritten by the remote's")
end

-- The atomic multi-ref publish (a save touching two items, one
-- contested) has its own test: `_work/storeref_test.tl`.

-- A rejection with the remote unmoved is remote policy, not a race.
-- The prepared transaction stays as the durable reachability root,
-- and the remote's own words reach the caller.
local function test_publish_keeps_the_mutation_on_a_policy_rejection()
  local bare, clones = init_shared("policy", 1)
  local a = check.must(store.open(clones[1]))
  local hook = fs.join(bare, "hooks", "pre-receive")
  assert(fs.write(hook,
      "#!/bin/sh\necho 'policy: board is read-only' >&2\nexit 1\n"))
  assert(fs.set_mode(hook, fs.octal("755")))

  local it = make_item("session-a")
  assert(storewrite.save(a, it, "new under policy"))
  local ok, err = publish.publish(a, true)
  assert(not ok, "the rejected push must refuse")
  assert(err ~= store.LOST_RACE and not err:find("lost the push race", 1, true),
    "no race is claimed when the remote never moved: " .. err)
  assert(err:find("policy: board is read-only", 1, true),
    "the remote's own words reach the caller: " .. err)
  local staged = check.must(prepared.list(a.root))
  assert(#staged == 1,
    "the rejected successor stays reachable through its prepared transaction")
  assert(staged[1].updates[1].ref == "refs/heads/items/" .. it.id,
    "the retryable transaction still targets the requested item")
  local reachable = check.must(child.run(
      {"git", "cat-file", "-e", staged[1].updates[1].next .. "^{commit}"},
      {cwd = a.root}))
  assert(reachable.ok, "the staged successor remains reachable for retry")
end
