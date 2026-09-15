#!/usr/bin/env cosmic
-- Whole-set claim policy and one full-board snapshot on canonical claim files.
local boardread = require("_work.boardread")
local check = require("cosmic.check")
local fixture = require("_work.fixture")
local stateclaim = require("_work.stateclaim")
local statepublish = require("_work.snapshot_publish")
local statewrite = require("_work.statewrite")
local store = require("_work.store")
local workspace = require("_work.snapshot_workspace")

local NOW < const > = os.time()
local BASE < const > = "0123456789012345678901234567890123456789"
local ALICE < const > = "0123456789abcdef0123456789abcdef"
local BOB < const > = "abcdef0123456789abcdef0123456789"

local function requests(ids: {string}): {stateclaim.Request}
  local out: {stateclaim.Request} = {}
  for _, id in ipairs(ids) do
    out[#out + 1] = {id = id, product_base = BASE}
  end
  return out
end

local function prepare(s: store.Store, ids: {string}, action?: stateclaim.Action,
    caller?: string, now?: integer, force?: boolean,
    why?: string): stateclaim.Result
  return stateclaim.prepare(s.root, s.state_head, requests(ids),
    action or "take", caller or ALICE, now or NOW, force or false, why or "")
end

local function stage(s: store.Store, result: stateclaim.Result)
  assert(next(result.refused) == nil, result.refused.batch)
  for _, dependency in ipairs(result.dependencies) do
    s.state_paths[dependency.path] = dependency.id
    s.state_reads[dependency.path] = dependency.id
  end
  s.session, s.op = ALICE, "claim"
  assert(statewrite.transition(s, result.changes, "claim fixture",
      result.publish_by))
end

local function test_policy_refusal_leaves_no_prepared_transaction()
  local s = fixture.init_state_repo("claim-policy-refusal")
  local id = fixture.file_item(s, "valid member", "")
  local result = prepare(s, {id, "does_not_exist"})
  assert(result.refused.does_not_exist ~= nil)
  assert(#result.changes == 0 and #result.members == 0)
  assert(workspace.read(s.root) == nil,
    "a policy-invalid member must leave no snapshot subset")
end

local function test_duplicate_member_rejects_the_whole_set()
  local s = fixture.init_state_repo("claim-duplicate")
  local id = fixture.file_item(s, "duplicate member", "")
  local result = prepare(s, {id, id})
  assert((result.refused[id] or ""):find("more than once", 1, true))
  assert(#result.changes == 0 and #result.members == 0)
end

local function test_foreign_overlap_cannot_be_forced()
  local s = fixture.init_state_repo("claim-force")
  local id = fixture.file_item(s, "force target", "")
  stage(s, prepare(s, {id}))
  assert(statepublish.publish(s))

  local denied = prepare(s, {id}, "take", BOB, NOW + 1)
  assert(denied.refused[id] ~= nil and #denied.changes == 0)
  local unsafe = prepare(s, {id}, "take", BOB, NOW + 1, true)
  assert(unsafe.refused[id] ~= nil and #unsafe.changes == 0)
  local forced = prepare(s, {id}, "take", BOB, NOW + 1, true,
    "the original session is gone")
  assert(forced.refused[id] ~= nil and #forced.members == 0 and #forced.changes == 0)
end

local function test_one_snapshot_contains_the_whole_set()
  local s = fixture.init_state_repo("claim-recovery")
  local a = fixture.file_item(s, "recover a", "")
  local b = fixture.file_item(s, "recover b", "")
  local result = prepare(s, {a, b})
  stage(s, result)
  local candidate = check.must(workspace.activate(s.root))
  assert(candidate.commit == s.state_head and candidate.claims_changed)
  local view = check.must(boardread.list(s.root, candidate.commit))
  assert(view.claims_by_id[a] ~= nil and view.claims_by_id[b] ~= nil,
    "both members are present in the one retained snapshot")
  assert(result.publish_by == view.claims_by_id[a].expires_at
    and result.publish_by == view.claims_by_id[b].expires_at)
end
