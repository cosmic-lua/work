#!/usr/bin/env cosmic
-- Archive acceptance is fail-closed: no shallow/promisor source, no corrupt or
-- disconnected pack, no cross-board state, and no half-created restore target.
local check = require("cosmic.check")
local child = require("cosmic.child")
local codec = require("cosmic.codec")
local fs = require("cosmic.fs")
local git = require("_work.singlehead_git")
local objects = require("_work.singlehead_objects")
local refs = require("_work.refs")

local BASE < const > = assert(os.getenv("TEST_TMPDIR"))
local REPOSITORY < const > = "example/board"
local BRANCH < const > = "envelope-poc"
local ITEM < const > = "refs/heads/items/adversarial"

local function init(name: string): string
  local root = fs.join(BASE, name)
  assert(fs.make_dirs(root))
  local result = check.must(child.run(
      {"git", "init", "--quiet", "--object-format=sha1"}, {cwd = root}))
  assert(result.ok, result.stderr)
  return root
end

local record Fixture
  source: string
  envelope: string
  target: string
  packed: string
  head: string
  state: objects.State
end

local function fixture(name: string): Fixture
  local source, envelope = init(name .. "-source"), init(name .. "-envelope")
  local tree = check.must(objects.make_tree(source, {{path = "meta",
          mode = "100644", otype = "blob", content = "title: adversarial\n"}}))
  local target = check.must(objects.make_commit(source, tree, "item\n"))
  local packed = check.must(objects.pack_objects(source, {target}))
  local digest = objects.sha256(packed)
  local state: objects.State = {format = objects.FORMAT,
    repository = REPOSITORY, branch = BRANCH, refs = {[ITEM] = target},
    packs = {{sha256 = digest, chunks = 1}}, receipts = {}}
  local content = check.must(objects.encode_state(state))
  local envelope_tree = check.must(objects.make_tree(envelope, {
        {path = objects.pack_path(digest), mode = "100644", otype = "blob",
          content = codec.encode_base64(packed) .. "\n"},
        {path = objects.STATE_PATH, mode = "100644", otype = "blob",
          content = content},
      }))
  local head = check.must(objects.make_commit(envelope, envelope_tree,
      "envelope\n"))
  return {source = source, envelope = envelope, target = target,
    packed = packed, head = head, state = state}
end

local function replace_pack(f: Fixture, bytes: string, digest: string): string
  local tree = check.must(objects.make_tree(f.envelope, {{path = objects.pack_path(digest),
          mode = "100644", otype = "blob",
          content = codec.encode_base64(bytes) .. "\n"}},
      check.must(objects.read_commit_tree(f.envelope, f.head))))
  return check.must(objects.make_commit(f.envelope, tree, "damaged envelope\n",
      f.head))
end

local function test_state_and_pack_are_bound_and_fully_validated()
  local f = fixture("singlehead-archive-binding")
  assert(check.must(objects.encode_state(f.state)):sub(1, 7) == "return ")
  assert(objects.read_validated_archive(f.envelope, f.head,
      REPOSITORY, BRANCH) ~= nil)
  local archive, err = objects.read_validated_archive(f.envelope, f.head,
    "other/board", BRANCH)
  assert(archive == nil and err:find("different repository", 1, true), err)
  archive, err = objects.read_validated_archive(f.envelope, f.head,
    REPOSITORY, "other-envelope")
  assert(archive == nil and err:find("different branch", 1, true), err)

  local corrupt = replace_pack(f, "corrupt", f.state.packs[1].sha256)
  archive, err = objects.read_validated_archive(f.envelope, corrupt,
    REPOSITORY, BRANCH)
  assert(archive == nil and err:find("corrupt envelope pack", 1, true), err)

  local legacy_tree = check.must(objects.make_tree(f.envelope, {{path = "gitboard/state.json",
          mode = "100644", otype = "blob", content = "{}\n"}}))
  local legacy = check.must(objects.make_commit(f.envelope, legacy_tree, "legacy envelope\n"))
  archive, err = objects.read_validated_archive(f.envelope, legacy, REPOSITORY, BRANCH)
  assert(archive == nil and err:find("gitboard-single-head-v1", 1, true), err)
end

local function test_disconnected_pack_and_incomplete_sources_refuse()
  local f = fixture("singlehead-connectivity")
  -- Object-list mode deliberately packs the commit without its tree/blob.
  local incomplete = check.must(git.run(f.source, {"pack-objects", "--stdout"},
      f.target .. "\n"))
  local ok, err = objects.validate_object_graph({incomplete}, {f.target})
  assert(not ok and (err:find("corrupt", 1, true)
      or err:find("incomplete", 1, true)), err)

  assert(fs.write(fs.join(f.source, ".git", "shallow"), f.target .. "\n"))
  ok, err = objects.source_is_complete(f.source)
  assert(not ok and err:find("shallow source", 1, true), err)
  assert(fs.remove(fs.join(f.source, ".git", "shallow")))
  local configured = check.must(child.run(
      {"git", "config", "remote.origin.promisor", "true"}, {cwd = f.source}))
  assert(configured.ok, configured.stderr)
  ok, err = objects.source_is_complete(f.source)
  assert(not ok and err:find("partial/promisor source", 1, true), err)
end

local function test_relative_repository_paths_are_resolved_once()
  local f = fixture("singlehead-relative-path")
  local relative = fs.relative_path(f.source)
  assert(not fs.is_absolute(relative), relative)
  check.must(git.run(relative, {"update-ref", ITEM, f.target}))
  local observed = check.must(objects.snapshot(relative, "refs/heads/"))
  assert(observed[ITEM] == f.target)
  local packed = check.must(objects.pack_objects(relative, {f.target}))
  assert(objects.sha256(packed) ~= "")
end

local function test_failed_restore_leaves_a_clean_retry_target()
  local f = fixture("singlehead-restore-retry")
  local destination = fs.join(BASE, "singlehead-restored")
  local corrupt = replace_pack(f, "corrupt", f.state.packs[1].sha256)
  local state, err = objects.restore(f.envelope, corrupt, destination)
  assert(state == nil and err:find("corrupt envelope pack", 1, true), err)
  assert(not fs.is_present(destination),
    "failed validation must not publish a partial destination")
  state, err = objects.restore(f.envelope, f.head, destination)
  assert(state ~= nil, err)
  assert(check.must(refs.read_ref(destination, ITEM)) == f.target)
end
