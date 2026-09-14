#!/usr/bin/env cosmic
-- Completing an accepted research item: its judged head is a board
-- commit, so `--landed` names that same commit and is verified in the
-- board checkout — there is no product landing to prove.
local check = require("cosmic.check")
local flow = require("_work.commit_flow_fixture")
local done = require("_work.gitdone")
local fixture = require("_work.fixture")
local gitboard = require("_work.gitboard")
local graph = require("_work.gitgraph")
local gittake = require("_work.gittake")
local item = require("_work.item")
local store = require("_work.store")
local publication = require("_work.snapshot_publish")
local workspace = require("_work.snapshot_workspace")
local verdict = require("_work.gitverdict")

-- The research handover, accepted: builder hands the board state over
-- with `take --result` and drops, the reviewer claims and accepts the
-- recorded board commit, and the lander claims to close it.
local function accepted_research(name: string): store.Store, string,
  flow.Product, string
  local s, id, p = flow.fresh(name)
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  check.must(store.list(s))
  local it = check.must(store.load(s, id))
  assert(item.record_involvement(it.builders, flow.BUILDER))
  assert(gittake.take_result(s, it, flow.BUILDER, 0) == 0)
  assert(flow.claim(s, id, flow.BUILDER, p, "drop") == 0)
  assert(flow.claim(s, id, flow.REVIEWER, p) == 0)
  local result = check.must(store.load(s, id)).result or ""
  assert(verdict.cmd_verdict_commit(s, id, "accept", result,
      flow.REVIEWER, false, "", p.root) == 0)
  assert(flow.claim(s, id, flow.REVIEWER, p, "drop") == 0)
  assert(flow.claim(s, id, flow.LANDER, p) == 0)
  return s, id, p, result
end

local function test_research_completes_with_its_board_commit_landed()
  local s, id, _p, result = accepted_research("done-research-landed")
  -- No `--repo-dir` and no repository mapping: the landing is the board
  -- commit itself, so the product checkout is never resolved.
  assert(done.cmd_done(s, id, "completed", false, "", "", result,
      "", flow.LANDER) == 0)
  local it = check.must(store.load(s, id))
  assert(it.resolution == "completed" and it.landed_head == result)
  assert(it.verdict_head == result and it.claim == flow.LANDER)
end

local function test_a_landing_other_than_the_result_is_refused()
  local s, id, p = accepted_research("done-research-other")
  assert(done.cmd_done(s, id, "completed", false, "", "", p.next_head,
      p.root, flow.LANDER) ~= 0,
    "a product commit does not land a research item")
  local it = check.must(store.load(s, id))
  assert((it.resolution or "") == "" and (it.landed_head or "") == "")
end

local function test_accepted_research_requires_a_landed_commit()
  local s, id, p = accepted_research("done-research-required")
  assert(done.cmd_done(s, id, "completed", false, "", "", "",
      p.root, flow.LANDER) ~= 0)
  assert((check.must(store.load(s, id)).resolution or "") == "")
end

local function outcome_membership_race(name: string): store.Store,
  store.Store, string, string, string
  local a, b = fixture.init_shared(name)
  local outcome = fixture.file_item(a, "an outcome", "")
  local evidence = fixture.file_item(a, "completed evidence", outcome)
  assert(done.cmd_done(a, evidence, "completed", false, "") == 0)
  fixture.caller_publish(a)
  local newcomer = fixture.file_item(a, "unpositioned newcomer", "")
  fixture.caller_fetch(b)
  return a, b, outcome, evidence, newcomer
end

local function publish_conflicts_and_abandons(s: store.Store)
  local candidate = check.must(workspace.read(s.root))
  local ok, err = publication.execute(s.root, candidate.commit, "origin", nil)
  assert(not ok and err:find("conflict", 1, true), err)
  assert(gitboard.main("snapshot", "--abandon", candidate.commit,
      "--dir", s.root) == 0)
  fixture.caller_fetch(s)
end

-- Outcome completion's no-open-child decision is bound to its complete base
-- snapshot. A later child attach advances the head, so the stale completion
-- conflicts wholesale and cannot close the now-open outcome by replay.
local function test_done_snapshot_before_open_child_attach_is_refused()
  local closer, attacher, outcome, evidence, newcomer =
  outcome_membership_race("done-before-attach")
  assert(done.cmd_done(closer, outcome, "completed", false, "", evidence) == 0)
  assert(graph.cmd_attach(attacher, newcomer, outcome) == 0)
  fixture.caller_publish(attacher)
  publish_conflicts_and_abandons(closer)
  assert((check.must(store.load(closer, outcome)).resolution or "") == "",
    "the outcome stays open after the competing child attach")
end

-- In the reverse order, attach has observed the parent as open. Closing the
-- outcome first moves that parent path, so the stale attach cannot turn the
-- completed outcome into a container without an explicit fresh decision.
local function test_open_child_attach_snapshot_before_done_is_refused()
  local closer, attacher, outcome, evidence, newcomer =
  outcome_membership_race("attach-before-done")
  assert(graph.cmd_attach(attacher, newcomer, outcome) == 0)
  assert(done.cmd_done(closer, outcome, "completed", false, "", evidence) == 0)
  fixture.caller_publish(closer)
  publish_conflicts_and_abandons(attacher)
  assert(check.must(store.load(attacher, outcome)).resolution == "completed",
    "the completed outcome is not reopened as a container by replay")
end
