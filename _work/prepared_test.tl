#!/usr/bin/env cosmic
-- Prepared transaction invariants: mutation objects remain detached
-- from canonical refs until publication, caller instructions require
-- atomic leased Git transport, and refresh only observes refs that a
-- caller has already fetched.
local check = require("cosmic.check")
local child = require("cosmic.child")
local fixture = require("_work.fixture")
local gitobj = require("_work.gitobj")
local prepared = require("_work.prepared")
local refs = require("_work.refs")

local function next_commit(root: string, parent: string,
    message: string): string
  local tree = check.must(gitobj.tree_of(root, parent))
  return check.must(gitobj.commit_tree(root, {
        tree = tree, parents = {parent}, message = message,
        author_name = "test", author_email = "test@example.com",
        committer_name = "test", committer_email = "test@example.com",
      }))
end

local function one_update(name: string): string, string, string, prepared.Transaction
  local s = fixture.init_state_repo(name)
  local id = fixture.file_item(s, "prepared transaction target", "")
  local target = "refs/heads/items/" .. id
  local old = check.must(refs.read_ref(s.root, target))
  local next_sha = next_commit(s.root, old, "prepared successor")
  local tx = check.must(prepared.prepare(s.root, {
        {ref = target, expected = old, next = next_sha},
      }, "prepare test transaction"))
  return s.root, old, next_sha, tx
end

local function test_prepare_is_git_native_and_does_not_move_the_target()
  local root, old, next_sha, tx = one_update("prepared-detached")
  assert(check.must(refs.read_ref(root, tx.staging_ref)) == tx.manifest)
  assert(check.must(refs.read_ref(root, tx.updates[1].ref)) == old,
    "preparation must not move canonical state")
  assert(tx.updates[1].expected == old and tx.updates[1].next == next_sha)

  local roundtrip = check.must(prepared.load(root, tx.staging_ref))
  assert(roundtrip.manifest == tx.manifest)
  assert(roundtrip.updates[1].ref == tx.updates[1].ref)

  local argv = prepared.push_argv(tx)
  assert(argv[1] == "git" and argv[2] == "push" and argv[3] == "--atomic")
  local rendered = table.concat(argv, " ")
  assert(rendered:find("--force-with-lease=" .. tx.updates[1].ref .. ":" .. old,
      1, true), rendered)
  assert(rendered:find(next_sha .. ":" .. tx.updates[1].ref, 1, true), rendered)
end

local function test_local_mode_promotes_all_refs_then_cleans_the_manifest()
  local root, _old, next_sha, tx = one_update("prepared-local-promote")
  assert(refs.set_board_mode(root, "local"))
  assert(prepared.promote_local(root, tx))
  assert(check.must(refs.read_ref(root, tx.updates[1].ref)) == next_sha)
  assert(check.must(refs.read_ref(root, tx.staging_ref)) == refs.ZERO_SHA,
    "confirmed staging refs are automatically cleaned")
end

local function test_refresh_observes_remote_tracking_refs_without_fetching()
  local root, old, next_sha, tx = one_update("prepared-remote-refresh")
  assert(refs.set_board_mode(root, "remote"))
  local tracked = check.must(refs.tracking_ref(tx.updates[1].ref))
  assert(refs.update_ref(root, tracked, old, refs.ZERO_SHA))

  local first = check.must(prepared.refresh(root))
  assert(#first == 1 and first[1].state == "pending")
  assert(check.must(refs.read_ref(root, tx.staging_ref)) == tx.manifest)

  -- This update stands in for the caller's already-completed fetch;
  -- refresh itself performs no network operation.
  assert(refs.update_ref(root, tracked, next_sha, old))
  local second = check.must(prepared.refresh(root))
  assert(#second == 1 and second[1].state == "confirmed")
  assert(check.must(refs.read_ref(root, tx.staging_ref)) == refs.ZERO_SHA)
  -- The old local head is irrelevant on a remote-backed board.
  assert(check.must(refs.read_ref(root, tx.updates[1].ref)) == old)
end

local function test_refresh_preserves_a_lost_race_for_diagnosis()
  local root, old, _next_sha, tx = one_update("prepared-lost-race")
  assert(refs.set_board_mode(root, "remote"))
  local tracked = check.must(refs.tracking_ref(tx.updates[1].ref))
  assert(refs.update_ref(root, tracked, old, refs.ZERO_SHA))
  local winner = next_commit(root, old, "some other writer won")
  assert(refs.update_ref(root, tracked, winner, old))

  local result = check.must(prepared.refresh(root))
  assert(#result == 1 and result[1].state == "lost-race")
  assert(check.must(refs.read_ref(root, tx.staging_ref)) == tx.manifest,
    "a losing transaction remains inspectable and is never replayed")
end

local function test_fetch_instructions_target_only_remote_tracking_refs()
  local argv = prepared.fetch_argv("upstream")
  local rendered = table.concat(argv, " ")
  assert(rendered == "git fetch --prune upstream "
    .. "+refs/heads/items/*:refs/remotes/upstream/items/* "
    .. "+refs/heads/ended/*:refs/remotes/upstream/ended/* "
    .. "+refs/heads/board/*:refs/remotes/upstream/board/*", rendered)
end

local function test_manifest_keeps_staged_successors_alive_through_aggressive_gc()
  local root, _old, next_sha, tx = one_update("prepared-gc-reachability")
  -- The successor is not named by a canonical ref: the prepared
  -- manifest's parent edge is its sole durable reachability path.
  local gc = check.must(child.run({"git", "reflog", "expire", "--expire=now",
        "--all"}, {cwd = root}))
  assert(gc.ok, gc.stderr)
  gc = check.must(child.run({"git", "gc", "--prune=now"}, {cwd = root}))
  assert(gc.ok, gc.stderr)
  local exists = check.must(child.run({"git", "cat-file", "-e",
        next_sha .. "^{commit}"}, {cwd = root}))
  assert(exists.ok, "the staged successor was pruned: " .. exists.stderr)

  assert(refs.set_board_mode(root, "local"))
  assert(prepared.promote_local(root, tx),
    "the GC-surviving successor remains promotable")
  assert(check.must(refs.read_ref(root, tx.updates[1].ref)) == next_sha)
end
