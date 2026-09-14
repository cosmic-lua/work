#!/usr/bin/env cosmic
--- Adversarial final-state checks for raw snapshot commits. Ordinary verbs
--- enforce these rules before composing; publication repeats them over the
--- complete parent and proposed trees so a hand-built COMMIT cannot bypass
--- the verb boundary.
local check = require("cosmic.check")
local flow = require("_work.commit_flow_fixture")
local gittake = require("_work.gittake")
local item = require("_work.item")
local publication = require("_work.snapshot_publish")
local store = require("_work.store")
local write = require("_work.storewrite")
local verdict = require("_work.gitverdict")
local workspace = require("_work.snapshot_workspace")

local function proposed(s: store.Store, it: item.Item, author: string,
    message: string): string
  write.set_session(s, author)
  local ok, err = write.save(s, it, message)
  assert(ok, err)
  return check.must(workspace.read(s.root)).commit
end

local function denied(s: store.Store, commit: string, needle: string)
  local planned, err = publication.plan(s.root, commit, "origin", nil)
  assert(planned == nil and err:find(needle, 1, true), err)
end

local function review_ready(name: string): store.Store, string,
  flow.Product
  local s, id, product = flow.fresh(name)
  assert(flow.claim(s, id, flow.BUILDER, product) == 0)
  assert(flow.handover(s, id, flow.BUILDER, product, product.head) == 0)
  assert(flow.claim(s, id, flow.BUILDER, product, "drop") == 0)
  assert(flow.claim(s, id, flow.REVIEWER, product) == 0)
  return s, id, product
end

local function test_forced_raw_verdict_still_belongs_to_canonical_holder()
  local s, id, product = review_ready("snapshot-verdict-holder")
  local it = check.must(store.load(s, id))
  it.verdict, it.verdict_head = "accept", product.head
  local commit = proposed(s, it, flow.OTHER,
    "raw accept\n\nForce-Why: attempted foreign repair")
  denied(s, commit, "canonical claim holder")
end

local function test_attribution_cannot_be_cleared_to_evade_review_distance()
  local s, id, product = review_ready("snapshot-attribution-clear")
  local it = check.must(store.load(s, id))
  it.builders = {}
  it.verdict, it.verdict_head = "accept", product.head
  local commit = proposed(s, it, flow.REVIEWER, "raw attribution clear")
  denied(s, commit, "append-only")
end

local function test_same_snapshot_attribution_participates_in_distance_check()
  local s, id, product = review_ready("snapshot-attribution-add")
  local it = check.must(store.load(s, id))
  assert(item.record_involvement(it.builders, flow.REVIEWER))
  it.verdict, it.verdict_head = "accept", product.head
  local commit = proposed(s, it, flow.REVIEWER, "raw self attribution")
  denied(s, commit, "verdict author built")
end

local function test_existing_accept_cannot_be_rewritten_by_raw_commit()
  local s, id, product = review_ready("snapshot-accepted-change")
  assert(verdict.cmd_verdict_commit(s, id, "accept", product.head,
      flow.REVIEWER, false, "", product.root) == 0)
  local it = check.must(store.load(s, id))
  it.verdict = "request changes"
  local commit = proposed(s, it, flow.REVIEWER, "raw accepted rewrite")
  denied(s, commit, "accepted verdict cannot be changed")
end

local function accepted_research(name: string): store.Store, string,
  flow.Product, string
  local s, id, product = flow.fresh(name)
  assert(flow.claim(s, id, flow.BUILDER, product) == 0)
  check.must(store.list(s))
  local it = check.must(store.load(s, id))
  assert(item.record_involvement(it.builders, flow.BUILDER))
  assert(gittake.take_result(s, it, flow.BUILDER, 0) == 0)
  assert(flow.claim(s, id, flow.BUILDER, product, "drop") == 0)
  assert(flow.claim(s, id, flow.REVIEWER, product) == 0)
  local result = check.must(store.load(s, id)).result or ""
  assert(verdict.cmd_verdict_commit(s, id, "accept", result,
      flow.REVIEWER, false, "", product.root) == 0)
  assert(flow.claim(s, id, flow.REVIEWER, product, "drop") == 0)
  assert(flow.claim(s, id, flow.LANDER, product) == 0)
  return s, id, product, result
end

local function test_research_completion_names_its_published_result()
  local s, id, product, _result = accepted_research(
    "snapshot-research-landing")
  local it = check.must(store.load(s, id))
  it.resolution, it.landed_head = "completed", product.head
  local commit = proposed(s, it, flow.LANDER, "raw research completion")
  denied(s, commit, "does not name published result")
end
