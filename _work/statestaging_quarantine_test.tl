#!/usr/bin/env cosmic
-- Native lost-race quarantine is a two-ref CAS: it preserves the receipt and
-- speculative state through GC, never overwrites a conflicting destination,
-- and recognizes another observer completing the exact same retirement.
local check = require("cosmic.check")
local child = require("cosmic.child")
local fixture = require("_work.fixture")
local gitobj = require("_work.gitobj")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local refs = require("_work.refs")
local staging = require("_work.statestaging")
local write = require("_work.storewrite")

local function setup(name: string): string, staging.Receipt, string
  local s = fixture.init_state_repo(name)
  local it = check.must(item.decode({id = ksuid.new(), title = "quarantine source"}))
  assert(write.save(s, it, "stage quarantine source"))
  local receipt = check.must(staging.load(s.root, s.state_receipt))
  return s.root, receipt,
  "refs/gitboard/quarantined/lost-race/" .. receipt.id
end

local function interleave(root: string, action: function(), run: function())
  local original = refs.update_refs_atomic
  local fired = false
  refs.update_refs_atomic = function(path: string, updates: {refs.RefUpdate},
      checks?: {refs.RefCheck}): boolean, string
    if path == root and not fired then fired = true; action() end
    return original(path, updates, checks)
  end
  local ok, err = pcall(run)
  refs.update_refs_atomic = original
  assert(ok, tostring(err))
  assert(fired, "retirement reached the atomic seam")
end

local function test_quarantine_retains_manifest_and_speculative_tip_through_gc()
  local root, receipt, destination = setup("native-quarantine-gc")
  assert(staging.retire(root, receipt))
  assert(check.must(refs.read_ref(root, receipt.ref)) == refs.ZERO_SHA)
  assert(check.must(refs.read_ref(root, destination)) == receipt.sha)
  for _, argv in ipairs({
      {"git", "reflog", "expire", "--expire=now", "--all"},
      {"git", "gc", "--prune=now"},
    }) do
    local result = check.must(child.run(argv, {cwd = root}))
    assert(result.ok, result.stderr)
  end
  local manifest = check.must(gitobj.cat_file_batch(root,
      {receipt.sha .. ":manifest"}))
  assert(manifest[receipt.sha .. ":manifest"] ~= nil)
  local retained = check.must(child.run(
      {"git", "cat-file", "-e", receipt.tip .. "^{commit}"}, {cwd = root}))
  assert(retained.ok, retained.stderr)
  assert(refs.is_ancestor(root, receipt.tip, receipt.sha))
end

local function test_conflicting_destination_is_never_overwritten()
  local root, receipt, destination = setup("native-quarantine-conflict")
  assert(refs.update_ref(root, destination, receipt.tip, refs.ZERO_SHA))
  local ok, err = staging.retire(root, receipt)
  assert(not ok and err:find("another receipt", 1, true), err)
  assert(check.must(refs.read_ref(root, receipt.ref)) == receipt.sha)
  assert(check.must(refs.read_ref(root, destination)) == receipt.tip)
end

local function test_changed_source_aborts_destination_creation()
  local root, receipt, destination = setup("native-quarantine-source-race")
  interleave(root, function()
      assert(refs.update_ref(root, receipt.ref, receipt.tip, receipt.sha))
    end, function()
      local ok, err = staging.retire(root, receipt)
      assert(not ok and err ~= "")
    end)
  assert(check.must(refs.read_ref(root, receipt.ref)) == receipt.tip)
  assert(check.must(refs.read_ref(root, destination)) == refs.ZERO_SHA)
end

local function test_destination_race_preserves_the_source()
  local root, receipt, destination = setup("native-quarantine-destination-race")
  interleave(root, function()
      assert(refs.update_ref(root, destination, receipt.tip, refs.ZERO_SHA))
    end, function()
      local ok, err = staging.retire(root, receipt)
      assert(not ok and err ~= "")
    end)
  assert(check.must(refs.read_ref(root, receipt.ref)) == receipt.sha)
  assert(check.must(refs.read_ref(root, destination)) == receipt.tip)
end

local function test_cooperative_completion_of_the_same_receipt_succeeds()
  local root, receipt, destination = setup("native-quarantine-cooperative")
  interleave(root, function()
      assert(refs.update_refs_atomic(root, {
            {ref = destination, expected = refs.ZERO_SHA, next = receipt.sha},
            {ref = receipt.ref, expected = receipt.sha, next = refs.ZERO_SHA},
          }))
    end, function()
      local ok, err = staging.retire(root, receipt)
      assert(ok, err)
    end)
  assert(check.must(refs.read_ref(root, destination)) == receipt.sha)
  assert(check.must(refs.read_ref(root, receipt.ref)) == refs.ZERO_SHA)
end
