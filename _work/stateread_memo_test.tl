#!/usr/bin/env cosmic
--- An invocation reuses immutable native reads without sharing mutable Items.
local boardhistory = require("_work.boardhistory")
local boardread = require("_work.boardread")
local check = require("cosmic.check")
local fixture = require("_work.fixture")
local publish = require("_work.publish")
local snapshot_workspace = require("_work.snapshot_workspace")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

local function test_resolve_load_spec_history_share_one_snapshot()
  local seeded = fixture.init_state_repo("memo-read")
  local id = fixture.file_item(seeded, "Memo item", "")
  local s = check.must(store.open(seeded.root))
  local old_view, old_history = boardread.list, boardhistory.read
  local views, histories = 0, 0
  boardread.list = function(root: string, head: string, now?: integer): boardread.View | nil, string
    views = views + 1
    return old_view(root, head, now)
  end
  boardhistory.read = function(root: string, head: string, before?: string): boardhistory.History | nil, string
    histories = histories + 1
    return old_history(root, head, before)
  end
  local ok, err = pcall(function()
      assert(check.must(store.resolve(s, id:sub(1, 20))) == id)
      local first = check.must(store.load(s, id))
      first.title = "Caller mutation"
      first.order[#first.order + 1] = "never stored"
      local second = check.must(store.load(s, id))
      assert(second.title == "Memo item" and #second.order == 0)
      local prose = store.read_spec(s, id)
      prose.change = "Caller prose mutation"
      assert(store.read_spec(s, id).change ~= prose.change)
      assert(#check.must(publish.history(s, id)) == 1)
      assert(views == 1 and histories == 1, "one view and one history per head")
    end)
  boardread.list, boardhistory.read = old_view, old_history
  assert(ok, err)
  assert(store.close(s))
end

local function test_claim_projection_survives_the_independent_copy()
  local s = fixture.init_state_repo("memo-claim")
  local id = fixture.file_item(s, "Claimed memo", "")
  local acquisition = fixture.claim_item(s, id, "memo-holder")
  local loaded = check.must(store.load(s, id))
  assert(loaded.claim == "memo-holder" and loaded.claim_batch == acquisition)
  local product_base = loaded.claim_base
  loaded.claim, loaded.claim_batch, loaded.claim_base = "tampered", "", ""
  local again = check.must(store.load(s, id))
  assert(again.claim == "memo-holder" and again.claim_batch == acquisition)
  assert(again.claim_base == product_base and product_base ~= "")
end

local function test_composition_and_abandon_invalidate_the_head()
  local seeded = fixture.init_state_repo("memo-snapshot")
  local id = fixture.file_item(seeded, "Original", "")
  local s = check.must(store.open(seeded.root))
  local first = check.must(store.load(s, id))
  assert(#check.must(publish.history(s, id)) == 1)
  first.title = "Snapshot successor"
  assert(storewrite.save(s, first, "edit snapshot"))
  assert(check.must(store.load(s, id)).title == "Snapshot successor")
  assert(#check.must(publish.history(s, id)) == 2)
  local candidate = check.must(snapshot_workspace.read(seeded.root))
  assert(snapshot_workspace.clear(seeded.root, candidate.commit))
  assert(publish.sync(s))
  assert(check.must(store.load(s, id)).title == "Original")
  assert(#check.must(publish.history(s, id)) == 1)
end

local function test_cold_list_reuses_its_decoded_view_and_history()
  local seeded = fixture.init_state_repo("memo-cold-list")
  local id = fixture.file_item(seeded, "Cold memo item", "")
  local s = check.must(store.open(seeded.root))
  local old_view, old_history = boardread.list, boardhistory.read
  local views, histories = 0, 0
  boardread.list = function(root: string, head: string, now?: integer): boardread.View | nil, string
    views = views + 1
    return old_view(root, head, now)
  end
  boardhistory.read = function(root: string, head: string): boardhistory.History | nil, string
    histories = histories + 1
    return old_history(root, head)
  end
  local ok, err = pcall(function()
      local listed = check.must(store.list(s))
      assert(#listed > 0)
      assert(check.must(store.resolve(s, id)) == id)
      local loaded = check.must(store.load(s, id))
      loaded.title = "caller mutation"
      assert(check.must(store.load(s, id)).title == "Cold memo item")
      local _prose = store.read_spec(s, id)
      assert(#check.must(publish.history(s, id)) == 1)
      assert(views == 1 and histories == 1,
        ("cold list and later reads share one projection: %d views, %d histories"):format(views, histories))
    end)
  boardread.list, boardhistory.read = old_view, old_history
  assert(ok, err)
  assert(store.close(s))
end
