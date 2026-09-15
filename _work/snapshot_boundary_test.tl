#!/usr/bin/env cosmic
--- Raw commits must obey the same board and claim publication boundaries.
local check = require("cosmic.check")
local fixture = require("_work.fixture")
local git = require("_work.singlehead_git")
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local projection = require("_work.stateplan_git")
local snapshot = require("_work.snapshot")
local stateclaim = require("_work.stateclaim")
local store = require("_work.store")
local tx = require("_work.statetransaction")
local validate = require("_work.snapshot_validate")
local workspace = require("_work.snapshot_workspace")
local write = require("_work.storewrite")

local function raw_commit(s: store.Store, parent: string, from: string,
    changes: {tx.Change}): string
  local tree = check.must(projection.apply(s.root, from, changes))
  local author: snapshot.Author = {name = "holder", email = "holder@board",
    date = tostring(os.time()) .. " +0000"}
  return check.must(git.text(s.root, {"commit-tree", tree, "-p", parent},
      check.must(snapshot.message("raw board update", author)), {
        GIT_AUTHOR_NAME = author.name, GIT_AUTHOR_EMAIL = author.email,
        GIT_AUTHOR_DATE = author.date, GIT_COMMITTER_NAME = "gitboard",
        GIT_COMMITTER_EMAIL = "gitboard@localhost", GIT_COMMITTER_DATE = author.date}))
end

local function refused(s: store.Store, parent: string, commit: string, reason: string)
  local report, err = validate.preflight(s.root, parent, commit, nil)
  assert(report == nil and err:find(reason, 1, true),
    err ~= "" and err or "raw snapshot accepted despite " .. reason)
end

local function test_raw_snapshot_cannot_mix_item_edit_and_claim_acquisition()
  local s = fixture.init_state_repo("snapshot-mixed-boundary")
  local board: item.Item | nil
  for _, it in ipairs(check.must(store.list(s))) do
    if item.is_parentless(it) then board = it; break end
  end
  assert(board ~= nil)
  local base = s.state_head
  local acquisition = stateclaim.prepare(s.root, base,
    {{id = board.id, product_base = string.rep("a", 40)}}, "take", "holder",
    os.time(), false, "")
  assert(next(acquisition.refused) == nil and #acquisition.changes == 1)
  write.set_session(s, "holder")
  board.title = "edited board"
  assert(write.save(s, board, "edit board"))
  local proposal = check.must(workspace.read(s.root))
  local mixed = raw_commit(s, base, proposal.commit, acquisition.changes)
  refused(s, base, mixed, "separate publication boundary")
end

local function test_raw_snapshot_cannot_publish_an_undeclared_board_path()
  local s = fixture.init_state_repo("snapshot-undeclared-path")
  local commit = raw_commit(s, s.state_head, s.state_head,
    {{path = "unrelated.txt", mode = "100644", content = "outside board", delete = false}})
  refused(s, s.state_head, commit, "undeclared board path")
end

local function test_raw_snapshot_cannot_add_migration_evidence()
  local s = fixture.init_state_repo("snapshot-migration-boundary")
  local commit = raw_commit(s, s.state_head, s.state_head,
    {{path = "migration/extra", mode = "100644", content = "invented evidence", delete = false}})
  refused(s, s.state_head, commit, "immutable migration evidence changed")
end

local function test_preflight_parent_must_match_the_proposed_commit()
  local s = fixture.init_state_repo("snapshot-parent-boundary")
  local board = check.must(store.list(s))[1]
  assert(item.is_parentless(board))
  local path = "items/" .. board.id .. "/meta"
  board.title = "first title"
  local first = raw_commit(s, s.state_head, s.state_head,
    {{path = path, mode = "100644", content = itemtree.encode_meta(board), delete = false}})
  board.title = "second title"
  local second = raw_commit(s, first, first,
    {{path = path, mode = "100644", content = itemtree.encode_meta(board), delete = false}})
  refused(s, s.state_head, second, "snapshot parent differs")
end
