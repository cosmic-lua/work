#!/usr/bin/env cosmic
local check = require("cosmic.check")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local boardread = require("_work.boardread")
local format = require("_work.format")
local refs = require("_work.refs")
local stateinit = require("_work.stateinit")
local stateevidence = require("_work.stateevidence")
local gitobj = require("_work.gitobj")
local projection = require("_work.stateplan_git")

local function test_native_bootstrap_is_atomic_and_idempotent()
  local root = fs.join(fixture.tmpdir, "native-init")
  assert(fs.remove_all(root))
  assert(stateinit.init(root))
  assert(refs.set_board_mode(root, "local"))
  local head = check.must(format.state_head(root))
  assert(head ~= "")
  local view = check.must(boardread.list(root, head))
  assert(#view.items == 1 and view.items[1].title == "board")
  assert(stateinit.init(root))
  assert(check.must(format.state_head(root)) == head)
  local legacy = check.must(refs.for_each_ref_raw(root, {"refs/heads/items", "refs/heads/claim-batches"}))
  assert(#legacy == 0, "native bootstrap must not create legacy board refs")
end

local function test_native_bootstrap_refuses_legacy_data()
  local s = fixture.init_state_repo("native-init-refuse")
  local before = check.must(refs.for_each_ref_raw(s.root, {"refs/heads/board/format"}))[1].sha
  local ok, err = stateinit.init(s.root)
  assert(not ok and err:find("migrate6", 1, true))
  local after = check.must(refs.for_each_ref_raw(s.root, {"refs/heads/board/format"}))[1].sha
  assert(before == after)
  assert(check.must(refs.read_ref(s.root, "refs/heads/state")) == refs.ZERO_SHA)
end

local function test_research_evidence_requires_item_attribution()
  local root = fs.join(fixture.tmpdir, "native-evidence")
  assert(fs.remove_all(root) and stateinit.init(root))
  local head = check.must(refs.read_ref(root, "refs/heads/state"))
  local view = check.must(boardread.list(root, head))
  local id = view.items[1].id
  local tree = check.must(projection.apply(root, head, {
        {path = "items/" .. id .. "/spec/change.md", mode = "100644", content = "research\n", delete = false}}))
  local result = check.must(gitobj.commit_tree(root, {tree = tree, parents = {head},
        message = "research result", author_name = "researcher", author_email = "r@board",
        committer_name = "gitboard", committer_email = "g@board"}))
  assert(check.must(stateevidence.verify(root, result, result, id)) == result)
  assert(stateevidence.read_spec(root, result, id).change == "research\n")
  local wrong = ("x"):rep(27)
  local accepted, err = stateevidence.verify(root, result, result, wrong)
  assert(accepted == nil and err:find("event of this item", 1, true))
  assert(select(1, stateevidence.verify(root, head, result, id)) == nil,
    "a speculative future result cannot be evidence on the fetched head")
  local original_tree = check.must(gitobj.cat_file_batch(root, {head}))[head].content:match("^tree ([0-9a-f]+)")
  assert(original_tree ~= nil)
  local primary = check.must(gitobj.commit_tree(root, {tree = original_tree, parents = {head},
        message = "ordinary board continuation", author_name = "gitboard", author_email = "g@board",
        committer_name = "gitboard", committer_email = "g@board"}))
  local merged = check.must(gitobj.commit_tree(root, {tree = tree, parents = {primary, result},
        message = "merge foreign evidence", author_name = "gitboard", author_email = "g@board",
        committer_name = "gitboard", committer_email = "g@board"}))
  local secondary, serr = stateevidence.verify(root, merged, result, id)
  assert(secondary == nil and serr:find("first-parent", 1, true),
    "second-parent reachability must not grant board evidence identity")
end
