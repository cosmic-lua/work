#!/usr/bin/env cosmic
-- Real local ref transactions, with deterministic interleavings at the CAS seam.
local check = require("cosmic.check")
local child = require("cosmic.child")
local fixture = require("_work.fixture")
local gitobj = require("_work.gitobj")
local prepared = require("_work.prepared")
local refs = require("_work.refs")

local function successor(root: string, old: string, message: string): string
  return check.must(gitobj.commit_tree(root, {
        tree = check.must(gitobj.tree_of(root, old)), parents = {old},
        message = message, author_name = "test", author_email = "test@example.com",
        committer_name = "test", committer_email = "test@example.com",
      }))
end

local function setup(name: string): string, prepared.Transaction, string, string
  local s = fixture.init_state_repo(name)
  local id = fixture.file_item(s, "quarantine source", "")
  local old = check.must(refs.read_ref(s.root, "refs/heads/items/" .. id))
  local a, b = "refs/heads/items/a", "refs/heads/items/b"
  assert(refs.update_refs_atomic(s.root, {
        {ref = a, expected = refs.ZERO_SHA, next = old},
        {ref = b, expected = refs.ZERO_SHA, next = old},
      }))
  local tx = check.must(prepared.prepare(s.root, {
        {ref = a, expected = old, next = successor(s.root, old, "first successor")},
        {ref = b, expected = old, next = successor(s.root, old, "second successor")},
      }))
  local winner = successor(s.root, old, "winning writer")
  assert(refs.update_ref(s.root, a, winner, old))
  return s.root, tx, winner, "refs/gitboard/quarantined/lost-race/" .. tx.id
end

local function interleave(root: string, action: function(), run: function())
  local original = refs.update_refs_atomic
  local fired = false
  refs.update_refs_atomic = function(path: string, updates: {refs.RefUpdate},
      checks?: {refs.RefCheck}): boolean, string
    if path == root and not fired then
      fired = true
      action()
    end
    return original(path, updates, checks)
  end
  local ok, err = pcall(run)
  refs.update_refs_atomic = original
  assert(ok, tostring(err))
  assert(fired, "the refresh must reach its atomic retirement seam")
end

local function test_same_destination_preserves_every_successor_through_gc()
  local root, tx, _winner, destination = setup("quarantine-gc")
  assert(refs.update_ref(root, destination, tx.manifest, refs.ZERO_SHA))
  local outcomes = check.must(prepared.refresh(root))
  assert(#outcomes == 1 and outcomes[1].state == "lost-race")
  assert(outcomes[1].quarantine_ref == destination)
  assert(check.must(refs.read_ref(root, tx.staging_ref)) == refs.ZERO_SHA)
  assert(check.must(refs.read_ref(root, destination)) == tx.manifest)
  assert(#check.must(prepared.refresh(root)) == 0)
  for _, argv in ipairs({
      {"git", "reflog", "expire", "--expire=now", "--all"},
      {"git", "gc", "--prune=now"},
    }) do
    local result = check.must(child.run(argv, {cwd = root}))
    assert(result.ok, result.stderr)
  end
  local manifest = check.must(gitobj.cat_file_batch(root, {destination .. ":manifest"}))
  assert(manifest[destination .. ":manifest"] ~= nil)
  for _, u in ipairs(tx.updates) do
    local result = check.must(child.run({"git", "cat-file", "-e", u.next .. "^{commit}"},
        {cwd = root}))
    assert(result.ok, "quarantine must retain EVERY successor: " .. result.stderr)
    assert(refs.is_ancestor(root, u.next, destination))
  end
end

local function test_conflicting_destination_is_never_overwritten()
  local root, tx, winner, destination = setup("quarantine-destination-conflict")
  assert(refs.update_ref(root, destination, winner, refs.ZERO_SHA))
  local result, err = prepared.refresh(root)
  assert(result == nil and err:find("different manifest", 1, true), err)
  assert(check.must(refs.read_ref(root, tx.staging_ref)) == tx.manifest)
  assert(check.must(refs.read_ref(root, destination)) == winner)
end

local function test_changed_source_aborts_destination_creation()
  local root, tx, winner, destination = setup("quarantine-source-race")
  interleave(root, function()
      assert(refs.update_ref(root, tx.staging_ref, winner, tx.manifest))
    end, function()
      local result, err = prepared.refresh(root)
      assert(result == nil and err ~= "", "a changed source must refuse retirement")
    end)
  assert(check.must(refs.read_ref(root, tx.staging_ref)) == winner)
  assert(check.must(refs.read_ref(root, destination)) == refs.ZERO_SHA)
end

local function test_changed_witness_aborts_retirement_and_preserves_work()
  local root, tx, winner, destination = setup("quarantine-witness-race")
  interleave(root, function()
      assert(refs.update_ref(root, tx.updates[1].ref, tx.updates[1].expected, winner))
    end, function()
      local result, err = prepared.refresh(root)
      assert(result == nil and err ~= "", "a changed witness must refuse retirement")
    end)
  assert(check.must(refs.read_ref(root, destination)) == refs.ZERO_SHA)
  assert(check.must(refs.read_ref(root, tx.staging_ref)) == tx.manifest)
  for _, u in ipairs(tx.updates) do
    assert(refs.is_ancestor(root, u.next, tx.staging_ref))
  end
end

local function test_destination_race_aborts_without_deleting_source()
  local root, tx, winner, destination = setup("quarantine-destination-race")
  interleave(root, function()
      assert(refs.update_ref(root, destination, winner, refs.ZERO_SHA))
    end, function()
      local result, err = prepared.refresh(root)
      assert(result == nil and err ~= "", "a changed destination must refuse retirement")
    end)
  assert(check.must(refs.read_ref(root, destination)) == winner)
  assert(check.must(refs.read_ref(root, tx.staging_ref)) == tx.manifest)
end

local function test_cooperative_completion_of_the_same_manifest_succeeds()
  local root, tx, _winner, destination = setup("quarantine-cooperative")
  interleave(root, function()
      assert(refs.update_refs_atomic(root, {
            {ref = destination, expected = refs.ZERO_SHA, next = tx.manifest},
            {ref = tx.staging_ref, expected = tx.manifest, next = refs.ZERO_SHA},
          }))
    end, function()
      local result = check.must(prepared.refresh(root))
      assert(result[1].state == "lost-race" and result[1].quarantine_ref == destination)
    end)
  assert(check.must(refs.read_ref(root, destination)) == tx.manifest)
  assert(#check.must(prepared.list(root)) == 0)
end

local function test_later_observation_errors_do_not_retire_an_earlier_conflict()
  for _, mapping_error in ipairs({false, true}) do
    local root, tx, _winner, destination = setup("quarantine-observation-error")
    local read, canonical = refs.read_ref, refs.canonical_ref
    if mapping_error then
      refs.canonical_ref = function(path: string, target: string,
          remote?: string): string | nil, string
        if target == tx.updates[2].ref then return nil, "injected mapping error" end
        return canonical(path, target, remote)
      end
    else
      refs.read_ref = function(path: string, ref: string): string | nil, string
        if ref == tx.updates[2].ref then return nil, "injected read error" end
        return read(path, ref)
      end
    end
    local result, err = prepared.refresh(root)
    refs.read_ref, refs.canonical_ref = read, canonical
    assert(result == nil and err ~= "")
    assert(check.must(refs.read_ref(root, tx.staging_ref)) == tx.manifest)
    assert(check.must(refs.read_ref(root, destination)) == refs.ZERO_SHA)
  end
end
