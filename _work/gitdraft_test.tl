#!/usr/bin/env cosmic
-- A draft is a durable speculative ref overlay: canonical refs stay still,
-- dependent writes see prior staged tips, and publication collapses the chain
-- to original -> final without making intermediate objects collectible.
local check = require("cosmic.check")
local child = require("cosmic.child")
local fixture = require("_work.fixture")
local gitdraft = require("_work.gitdraft")
local gitobj = require("_work.gitobj")
local prepared = require("_work.prepared")
local refs = require("_work.refs")

local function successor(root: string, parent: string, message: string): string
  local tree = check.must(gitobj.tree_of(root, parent))
  return check.must(gitobj.commit_tree(root, {tree = tree, parents = {parent},
        message = message, author_name = "test", author_email = "test@example.com",
        committer_name = "test", committer_email = "test@example.com"}))
end

local function mirror_board(root: string)
  local found = check.must(refs.for_each_ref_raw(root,
      {"refs/heads/items", "refs/heads/ended", "refs/heads/board"}))
  for _, entry in ipairs(found) do
    local tracked = check.must(refs.tracking_ref(entry.refname))
    assert(refs.update_ref(root, tracked, entry.sha, refs.ZERO_SHA))
  end
end

local function test_dependent_writes_are_offline_and_collapse_to_one_update()
  local s = fixture.init_state_repo("draft-chain")
  local id = fixture.file_item(s, "draft target", "")
  local target = "refs/heads/items/" .. id
  local original = check.must(refs.read_ref(s.root, target))
  local draft = check.must(gitdraft.begin(s.root))
  assert(check.must(gitdraft.tip(draft, target)) == original)

  local first = successor(s.root, original, "first offline mutation")
  draft = check.must(gitdraft.stage(s.root, draft, {
        {ref = target, expected = original, next = first},
      }))
  assert(check.must(gitdraft.tip(draft, target)) == first)
  local second = successor(s.root, first, "dependent offline mutation")
  draft = check.must(gitdraft.stage(s.root, draft, {
        {ref = target, expected = first, next = second},
      }))

  assert(check.must(refs.read_ref(s.root, target)) == original,
    "offline staging must not move canonical refs")
  local plan = gitdraft.plan(draft)
  assert(#plan == 1)
  assert(plan[1].ref == target and plan[1].expected == original
    and plan[1].next == second)
end

local function test_snapshot_is_stable_and_new_refs_are_anchored_at_zero()
  local s = fixture.init_state_repo("draft-snapshot")
  local id = fixture.file_item(s, "existing target", "")
  local target = "refs/heads/items/" .. id
  local original = check.must(refs.read_ref(s.root, target))
  local draft = check.must(gitdraft.begin(s.root))

  local outside = successor(s.root, original, "outside change after begin")
  assert(refs.update_ref(s.root, target, outside, original))
  assert(check.must(gitdraft.tip(draft, target)) == original,
    "the overlay reads its immutable begin snapshot")

  local new_ref = "refs/heads/items/new_offline_item"
  assert(check.must(gitdraft.tip(draft, new_ref)) == refs.ZERO_SHA)
  local created = successor(s.root, original, "new item stand-in")
  draft = check.must(gitdraft.stage(s.root, draft, {
        {ref = new_ref, expected = refs.ZERO_SHA, next = created},
      }))
  local plan = gitdraft.plan(draft)
  assert(#plan == 1 and plan[1].expected == refs.ZERO_SHA)
end

local function test_draft_survives_process_boundaries_and_gc_then_aborts()
  local s = fixture.init_state_repo("draft-durable")
  local id = fixture.file_item(s, "durable target", "")
  local target = "refs/heads/items/" .. id
  local original = check.must(refs.read_ref(s.root, target))
  local draft = check.must(gitdraft.begin(s.root))

  -- Deliberately divergent objects: neither successor reaches the other, so
  -- only the manifest parent chain keeps both alive.
  local first = successor(s.root, original, "detached staged one")
  draft = check.must(gitdraft.stage(s.root, draft, {
        {ref = target, expected = original, next = first},
      }))
  local second = successor(s.root, original, "detached staged two")
  draft = check.must(gitdraft.stage(s.root, draft, {
        {ref = target, expected = first, next = second},
      }))

  local reopened = check.must(gitdraft.open(s.root, draft.id))
  assert(reopened.manifest == draft.manifest)
  assert(check.must(gitdraft.tip(reopened, target)) == second)
  local all = check.must(gitdraft.list(s.root))
  assert(#all == 1 and all[1].id == draft.id)

  local gc = check.must(child.run({"git", "reflog", "expire", "--expire=now",
        "--all"}, {cwd = s.root}))
  assert(gc.ok, gc.stderr)
  gc = check.must(child.run({"git", "gc", "--prune=now"}, {cwd = s.root}))
  assert(gc.ok, gc.stderr)
  for _, sha in ipairs({first, second}) do
    local exists = check.must(child.run({"git", "cat-file", "-e",
          sha .. "^{commit}"}, {cwd = s.root}))
    assert(exists.ok, "draft GC lost staged object " .. sha)
  end

  assert(gitdraft.abort(s.root, reopened))
  assert(#check.must(gitdraft.list(s.root)) == 0)
end

local function test_remote_frozen_anchor_survives_tracking_ref_deletion_and_gc()
  local s = fixture.init_state_repo("draft-remote-anchor-gc")
  local id = fixture.file_item(s, "anchor retained only by draft", "")
  local target = "refs/heads/items/" .. id
  local anchor = check.must(refs.read_ref(s.root, target))
  mirror_board(s.root)
  assert(refs.set_board_mode(s.root, "remote"))
  local draft = check.must(gitdraft.begin(s.root))
  local tracked = check.must(refs.tracking_ref(target))
  assert(refs.update_ref(s.root, target, refs.ZERO_SHA, anchor))
  assert(refs.update_ref(s.root, tracked, refs.ZERO_SHA, anchor))
  local gc = check.must(child.run({"git", "reflog", "expire", "--expire=now",
        "--all"}, {cwd = s.root}))
  assert(gc.ok, gc.stderr)
  gc = check.must(child.run({"git", "gc", "--prune=now"}, {cwd = s.root}))
  assert(gc.ok, gc.stderr)
  local reopened = check.must(gitdraft.open(s.root, draft.id))
  assert(check.must(gitdraft.tip(reopened, target)) == anchor)
  assert(gitdraft.activate(s.root, reopened))
  local exists = check.must(child.run({"git", "cat-file", "-e",
        anchor .. "^{commit}"}, {cwd = s.root}))
  assert(exists.ok, "draft begin receipt did not retain its frozen anchor")
  gitdraft.deactivate(s.root)
end

local function test_stage_rejects_a_writer_not_based_on_the_overlay_tip()
  local s = fixture.init_state_repo("draft-cas")
  local id = fixture.file_item(s, "cas target", "")
  local target = "refs/heads/items/" .. id
  local original = check.must(refs.read_ref(s.root, target))
  local draft = check.must(gitdraft.begin(s.root))
  local first = successor(s.root, original, "first")
  draft = check.must(gitdraft.stage(s.root, draft, {
        {ref = target, expected = original, next = first},
      }))
  local wrong = successor(s.root, original, "wrong-base")
  local rejected, err = gitdraft.stage(s.root, draft, {
      {ref = target, expected = original, next = wrong},
    })
  assert(rejected == nil and err:find("draft tip mismatch", 1, true), err)

  -- The consolidated plan plugs directly into existing prepared transport.
  local tx = check.must(prepared.prepare(s.root, gitdraft.plan(draft)))
  local argv = table.concat(prepared.push_argv(tx), " ")
  assert(argv:find("--force-with-lease=" .. target .. ":" .. original,
      1, true), argv)
  assert(argv:find(first .. ":" .. target, 1, true), argv)
end
