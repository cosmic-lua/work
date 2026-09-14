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
local git = require("_work.singlehead_git")
local refs = require("_work.refs")
local itemtree = require("_work.itemtree")
local projection = require("_work.stateplan_git")
local receipts = require("_work.stateplan_receipts")
local transaction = require("_work.statetransaction")
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
  assert(refs.set_board_mode(root, "remote"))
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

local function test_new_publication_succeeds_with_an_unrelated_retained_conflict()
  local root = setup("native-own-publication-with-old-conflict")
  local losing = check.must(store.open(root))
  local contested = fresh()
  assert(write.save(losing, contested, "losing version"))
  local losing_receipt = check.must(staging.load(root, losing.state_receipt))
  local losing_plan = check.must(native.build(root, losing_receipt))
  losing_receipt.published = losing_plan.candidate
  losing_receipt = check.must(staging.write(root, losing_receipt,
      losing_receipt.sha))
  assert(store.close(losing))

  local winning = check.must(item.decode({id = contested.id,
        title = "winning version"}))
  local altered = {}
  for _, change in ipairs(losing_plan.frozen.transitions[1].changes) do
    altered[#altered + 1] = {path = change.path, mode = change.mode,
      content = change.path:match("/meta$") and itemtree.encode_meta(winning)
      or change.content, delete = change.delete}
  end
  local conflicting_tree = check.must(projection.apply(root,
      losing_plan.expected_head, altered))
  local conflicting_tip = check.must(projection.commit(root,
      losing_plan.expected_head, conflicting_tree,
      losing_plan.frozen.transitions[1]))
  assert(refs.update_ref(root, "refs/heads/state", conflicting_tip,
      losing_plan.expected_head))
  local clean, conflict = native.refresh(root, refs.board_remote(root))
  assert(not clean and conflict:find("conflict=1", 1, true), conflict)
  assert(check.must(staging.load(root, losing_receipt.ref)).sha
    == losing_receipt.sha, "the older conflicting receipt remains for diagnosis")

  local current = check.must(store.open(root))
  local disjoint = fresh()
  local disjoint_id = disjoint.id
  assert(write.save(current, disjoint, "fresh disjoint publication"))
  local published, detail = publish.publish(current)
  assert(published, detail)
  assert(detail:find("unrelated receipt warning", 1, true), detail)
  assert(detail:find("conflict=1", 1, true), detail)
  local remaining = check.must(staging.list(root))
  assert(#remaining == 1 and remaining[1].sha == losing_receipt.sha,
    "only the unrelated conflict remains")
  local verified = check.must(store.open(root))
  assert(check.must(store.load(verified, disjoint_id)).title
    == "lifecycle", "the successful publication is canonical")
  assert(store.close(verified))
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

local function test_published_snapshot_consumes_only_the_live_draft_prefix()
  local root = setup("native-refresh-published-draft-prefix")
  local initial = check.must(refs.read_ref(root, "refs/heads/state"))
  local draft = check.must(gitdraft.begin(root))
  assert(gitdraft.activate(root, draft))
  local s = check.must(store.open(root))
  local it = fresh()
  local id = it.id
  assert(write.save(s, it, "draft prefix A") and publish.publish(s))
  local first = check.must(staging.load(root, draft.staging_ref))
  local snapshot = check.must(staging.snapshot(root, first))
  local saved_snapshot = check.must(transaction.encode(check.must(staging.frozen(snapshot))))

  it.title = "advanced suffix B"
  assert(write.save(s, it, "draft suffix B") and publish.publish(s))
  local advanced = check.must(staging.load(root, draft.staging_ref))
  assert(#advanced.transitions == 2)
  local advanced_tip = advanced.tip
  gitdraft.deactivate(root)
  assert(store.close(s))

  local published, detail = native.execute(root, snapshot)
  assert(published, detail)
  snapshot = check.must(staging.load(root, snapshot.ref))
  assert(check.must(transaction.encode(check.must(staging.frozen(snapshot)))) == saved_snapshot,
    "recording publication must not change the prepared snapshot")

  -- Let an unrelated writer land after A. Refresh must preserve it as the new
  -- base for B rather than reconstructing A or publishing from the old base.
  local disjoint_store = check.must(store.open(root))
  local disjoint = fresh()
  local disjoint_id = disjoint.id
  assert(write.save(disjoint_store, disjoint, "disjoint canonical C"))
  local disjoint_receipt = check.must(staging.load(root, disjoint_store.state_receipt))
  assert(native.execute(root, disjoint_receipt))
  assert(store.close(disjoint_store))
  local after_disjoint = check.must(refs.read_ref(root, "refs/heads/state"))

  local clean, report = native.refresh(root, refs.board_remote(root))
  assert(clean and report:find("confirmed=2 pending=1 conflict=0", 1, true), report)
  assert(check.must(refs.read_ref(root, snapshot.ref)) == refs.ZERO_SHA,
    "the immutable A snapshot is retired only after its complete chain is proved")
  local suffix = check.must(staging.load(root, draft.staging_ref))
  assert(suffix.sha ~= advanced.sha and suffix.tip == advanced_tip)
  assert(suffix.base == after_disjoint and #suffix.transitions == 1)
  assert(suffix.transitions[1].base == after_disjoint)
  assert(suffix.transitions[1].message:find("draft suffix B", 1, true))

  local suffix_snapshot = check.must(staging.snapshot(root, suffix))
  local suffix_plan = check.must(native.build(root, suffix_snapshot))
  assert(#suffix_plan.frozen.transitions == 1,
    "the next publication contains B only, never the already canonical A")
  assert(native.execute(root, suffix_snapshot))
  assert(native.refresh(root, refs.board_remote(root)))
  assert(check.must(refs.read_ref(root, draft.staging_ref)) == refs.ZERO_SHA)
  local final = check.must(refs.read_ref(root, "refs/heads/state"))
  assert(check.must(git.text(root, {"rev-list", "--first-parent", "--count", final, "^" .. initial})) == "3")
  local subjects = check.must(git.text(root, {"log", "--first-parent", "--format=%s", final, "^" .. initial}))
  local _, prefix_count = subjects:gsub("draft prefix A", "")
  local _, suffix_count = subjects:gsub("draft suffix B", "")
  assert(prefix_count == 1 and suffix_count == 1, "A and B must each publish exactly once")
  local verified = check.must(store.open(root))
  assert(check.must(store.load(verified, id)).title == "advanced suffix B")
  assert(check.must(store.load(verified, disjoint_id)).title == "lifecycle")
  assert(store.close(verified))
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
  assert(refs.set_board_mode(root, "remote"))
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
