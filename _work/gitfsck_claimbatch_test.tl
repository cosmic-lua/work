#!/usr/bin/env cosmic
--- Native fsck diagnoses claim corruption even when ordinary projection refuses.
local boardtree = require("_work.boardtree")
local tx = require("_work.statetransaction")
local check = require("cosmic.check")
local fixture = require("_work.fixture")
local fsck = require("_work.gitfsck")
local gitobj = require("_work.gitobj")
local projection = require("_work.stateplan_git")
local refs = require("_work.refs")
local store = require("_work.store")

local function fsck_and_capture(s: store.Store): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, code = pcall(fsck.cmd_fsck, s)
  _G.print = old_print
  assert(ok, code)
  return code, table.concat(lines, "\n")
end

local function corrupt(s: store.Store, path: string, content: string, delete: boolean)
  local changes: {tx.Change} = {{path = path, mode = "100644", content = content, delete = delete}}
  if delete then
    changes = {}
    for _, entry in ipairs(check.must(boardtree.snapshot_tree_entries(s.root, s.state_head))) do
      if entry.mode ~= "040000" and entry.path:sub(1, #path + 1) == path .. "/" then
        changes[#changes + 1] = {path = entry.path, mode = entry.mode, content = "", delete = true}
      end
    end
    assert(#changes > 0, "remove actual item leaves")
  end
  local tree = check.must(projection.apply(s.root, s.state_head, changes))
  local sha = check.must(gitobj.commit_tree(s.root, {tree = tree, parents = {s.state_head},
        message = "external corrupt write", author_name = "test", author_email = "test@board",
        committer_name = "test", committer_email = "test@board"}))
  assert(refs.update_ref(s.root, "refs/heads/state", sha, s.state_head))
  s.state_head = sha
  assert(store.close(s))
end

local function test_a_claim_set_has_one_native_commit_and_no_orphan_members()
  local s = fixture.init_state_repo("fsck-native-claims")
  local first = fixture.file_item(s, "First claimed item", "")
  local second = fixture.file_item(s, "Second claimed item", "")
  local before = fixture.commits(s)
  fixture.control_claim(s, {first, second}, "fsck-holder")
  assert(fixture.commits(s) == before + 1, "the set is one mutation")
  local healthy, report = fsck_and_capture(s)
  assert(healthy == 0, report)
  corrupt(s, "items/" .. second, "", true)
  local code, out = fsck_and_capture(s)
  assert(code ~= 0 and out:find(second, 1, true), "an orphan claim is named: " .. out)
end

local function test_an_unreadable_claim_blob_is_named()
  local s = fixture.init_state_repo("fsck-native-corrupt-claim")
  local id = fixture.file_item(s, "Broken claim", "")
  corrupt(s, "claims/" .. id, "this is not a claim literal", false)
  local code, out = fsck_and_capture(s)
  assert(code ~= 0 and out:find("claims/" .. id, 1, true), out)
  local it, err = store.load(s, id)
  assert(it == nil and err:find("claims/" .. id, 1, true), "ordinary reads fail closed")
end
