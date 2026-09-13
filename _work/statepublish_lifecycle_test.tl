#!/usr/bin/env cosmic
local check = require("cosmic.check")
local child = require("cosmic.child")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local stateinit = require("_work.stateinit")
local store = require("_work.store")
local write = require("_work.storewrite")
local publish = require("_work.publish")
local native = require("_work.statepublish")
local prepared = require("_work.prepared")
local staging = require("_work.statestaging")
local gitdraft = require("_work.gitdraft")
local gitobj = require("_work.gitobj")
local refs = require("_work.refs")
local itemtree = require("_work.itemtree")
local receipts = require("_work.stateplan_receipts")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local function setup(name: string): string
  local root = fs.join(fixture.tmpdir, name)
  assert(fs.remove_all(root) and fs.make_dirs(root) and stateinit.init(root))
  assert(check.must(child.run({"git", "config", "gitboard.mode", "local"}, {cwd = root})).ok)
  return root
end
local function fresh(): item.Item
  return check.must(item.decode({id = ksuid.new(), title = "lifecycle"}))
end
local function test_five_failed_head_retries_retire_the_exact_attempt()
  local root = setup("native-retry-bound")
  local initial = check.must(refs.read_ref(root, "refs/heads/state"))
  assert(check.must(child.run({"git", "remote", "add", "origin", "https://example.invalid/fixture/board.git"}, {cwd = root})).ok)
  assert(check.must(child.run({"git", "config", "gitboard.mode", "remote"}, {cwd = root})).ok)
  assert(refs.update_refs_atomic(root, {
        {ref = "refs/remotes/origin/state", expected = refs.ZERO_SHA, next = initial},
        {ref = "refs/remotes/origin/board/format", expected = refs.ZERO_SHA, next = initial}}))
  local s = check.must(store.open(root))
  assert(write.save(s, fresh(), "new retry"))
  local receipt = check.must(staging.load(root, s.state_receipt))
  local original = prepared.execute
  local pushes = 0
  prepared.execute = function(dir: string, argv: {string}): boolean, string
    if argv[2] == "fetch" then return true, "" end
    assert(argv[2] == "push")
    pushes = pushes + 1
    local previous = check.must(refs.read_ref(dir, "refs/remotes/origin/state"))
    local tree = check.must(gitobj.tree_of(dir, previous))
    local next_head = check.must(gitobj.commit_tree(dir, {tree = tree, parents = {previous},
          message = "unrelated writer " .. tostring(pushes), author_name = "other", author_email = "other@board",
          committer_name = "gitboard", committer_email = "gitboard@board"}))
    assert(refs.update_ref(dir, "refs/remotes/origin/state", next_head, previous))
    return false, "simulated non-fast-forward rejection"
  end
  local ok, err = native.execute(root, receipt)
  prepared.execute = original
  assert(not ok and err == store.LOST_RACE, err)
  assert(pushes == 5, tostring(pushes))
  assert(check.must(refs.read_ref(root, receipt.ref)) == refs.ZERO_SHA)
  assert(check.must(refs.read_ref(root, "refs/gitboard/quarantined/lost-race/" .. receipt.id)) == receipt.sha)
end

local function test_retirement_never_removes_an_advanced_receipt()
  local root = setup("native-retire-advanced")
  local draft = check.must(gitdraft.begin(root))
  assert(gitdraft.activate(root, draft))
  local s = check.must(store.open(root))
  local it = fresh()
  assert(write.save(s, it, "first") and publish.publish(s))
  local old = check.must(staging.load(root, draft.staging_ref))
  it.title = "second"
  assert(write.save(s, it, "second") and publish.publish(s))
  local current = check.must(staging.load(root, draft.staging_ref))
  gitdraft.deactivate(root)
  local removed, err = staging.retire(root, old)
  assert(not removed and err:find("advanced", 1, true), err)
  assert(check.must(refs.read_ref(root, draft.staging_ref)) == current.sha)
end

local function test_refresh_rechecks_the_draft_after_its_ref_snapshot()
  local root = setup("native-refresh-advanced")
  local draft = check.must(gitdraft.begin(root))
  assert(gitdraft.activate(root, draft))
  local s = check.must(store.open(root))
  local it = fresh()
  assert(write.save(s, it, "first") and publish.publish(s))
  local old = check.must(staging.load(root, draft.staging_ref))
  gitdraft.deactivate(root)
  local plan = check.must(native.build(root, old))
  assert(refs.update_ref(root, "refs/heads/state", plan.candidate, plan.expected_head))
  assert(gitdraft.activate(root, check.must(gitdraft.open(root, draft.id))))
  it.title = "advanced after snapshot"
  assert(write.save(s, it, "second") and publish.publish(s))
  local current = check.must(staging.load(root, draft.staging_ref))
  gitdraft.deactivate(root)
  local original = staging.list
  staging.list = function(_root: string, _kind?: string): {staging.Receipt} | nil, string
    return {old}, ""
  end
  local ok, err = native.refresh(root, refs.board_remote(root))
  staging.list = original
  assert(ok and err:find("confirmed=0 pending=1", 1, true), err)
  assert(check.must(refs.read_ref(root, draft.staging_ref)) == current.sha)
end

local function test_refresh_preserves_a_published_attempt_beyond_the_search_cap()
  local root = setup("native-refresh-search-cap")
  local s = check.must(store.open(root))
  local it = fresh()
  assert(write.save(s, it, "published before a long history"))
  local receipt = check.must(staging.load(root, s.state_receipt))
  local projected = check.must(native.build(root, receipt))
  assert(refs.update_ref(root, "refs/heads/state", projected.candidate, projected.expected_head))
  it.title = "a later edit after the historical publication"
  local replacement = itemtree.encode_meta(it)
  local stream: {string} = {}
  for index = 1, receipts.SEARCH_LIMIT + 1 do
    local message = "later generation " .. tostring(index) .. "\n"
    stream[#stream + 1] = "commit refs/heads/state\ncommitter Later <later@board> 1700000000 +0000\ndata "
    .. tostring(#message) .. "\n" .. message
    if index == 1 then
      stream[#stream + 1] = "from " .. projected.candidate .. "\nM 100644 inline items/" .. it.id .. "/meta\ndata "
      .. tostring(#replacement) .. "\n" .. replacement .. "\n"
    end
    stream[#stream + 1] = "\n"
  end
  local imported = check.must(child.run({"git", "fast-import", "--quiet"}, {cwd = root, stdin = table.concat(stream)}))
  assert(imported.ok, imported.stderr)
  local observed = check.must(refs.read_ref(root, "refs/heads/state"))
  local proof = check.must(receipts.inspect(root, observed, check.must(staging.frozen(receipt))))
  assert(proof.status == "pending" and not proof.absence_proven)
  local ok, err = native.refresh(root, refs.board_remote(root))
  assert(ok and err:find("confirmed=0 pending=1", 1, true), err)
  assert(check.must(refs.read_ref(root, receipt.ref)) == receipt.sha)
  assert(check.must(refs.read_ref(root, "refs/gitboard/quarantined/lost-race/" .. receipt.id)) == refs.ZERO_SHA)
  receipt.published = projected.candidate
  check.must(staging.write(root, receipt, receipt.sha))
  assert(native.refresh(root, refs.board_remote(root)))
  assert(check.must(refs.read_ref(root, receipt.ref)) == refs.ZERO_SHA)
  local current = check.must(store.open(root))
  assert(check.must(store.load(current, it.id)).title == it.title)
end

local function test_fifth_push_lost_acknowledgement_is_confirmed_and_repeatable()
  local root = setup("native-fifth-lost-ack")
  local initial = check.must(refs.read_ref(root, "refs/heads/state"))
  assert(check.must(child.run({"git", "remote", "add", "origin", "https://example.invalid/fixture/board.git"}, {cwd = root})).ok)
  assert(check.must(child.run({"git", "config", "gitboard.mode", "remote"}, {cwd = root})).ok)
  assert(refs.update_refs_atomic(root, {
        {ref = "refs/remotes/origin/state", expected = refs.ZERO_SHA, next = initial},
        {ref = "refs/remotes/origin/board/format", expected = refs.ZERO_SHA, next = initial}}))
  local s = check.must(store.open(root))
  assert(write.save(s, fresh(), "lost acknowledgement"))
  local receipt = check.must(staging.load(root, s.state_receipt))
  local original = prepared.execute
  local pushes = 0
  prepared.execute = function(dir: string, argv: {string}): boolean, string
    if argv[2] == "fetch" then return true, "" end
    assert(argv[2] == "push")
    pushes = pushes + 1
    local previous = check.must(refs.read_ref(dir, "refs/remotes/origin/state"))
    local next_head: string
    if pushes == 5 then next_head = assert(argv[4]:match("^([^:]+):"))
    else
      next_head = check.must(gitobj.commit_tree(dir, {tree = check.must(gitobj.tree_of(dir, previous)), parents = {previous},
            message = "other writer " .. tostring(pushes), author_name = "other", author_email = "other@board",
            committer_name = "gitboard", committer_email = "gitboard@board"}))
    end
    assert(refs.update_ref(dir, "refs/remotes/origin/state", next_head, previous))
    return false, "transport lost acknowledgement"
  end
  local ok, err = native.execute(root, receipt)
  prepared.execute = original
  assert(ok and pushes == 5, err)
  receipt = check.must(staging.load(root, receipt.ref))
  assert(receipt.published == check.must(refs.read_ref(root, "refs/remotes/origin/state")))
  assert(native.execute(root, receipt))
  assert(check.must(refs.read_ref(root, "refs/gitboard/quarantined/lost-race/" .. receipt.id)) == refs.ZERO_SHA)
  assert(native.refresh(root, "origin"))
  assert(check.must(refs.read_ref(root, receipt.ref)) == refs.ZERO_SHA)
end

local function test_missing_receipt_is_not_evidence_of_retirement()
  local root = setup("native-missing-retirement")
  local s = check.must(store.open(root))
  assert(write.save(s, fresh(), "disappearing receipt"))
  local receipt = check.must(staging.load(root, s.state_receipt))
  assert(staging.remove(root, receipt))
  local retired, err = staging.retire(root, receipt)
  assert(not retired and err:find("disappeared", 1, true), err)
end
