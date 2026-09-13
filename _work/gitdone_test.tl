#!/usr/bin/env cosmic
-- Completing an accepted research item: its judged head is a board
-- commit, so `--landed` names that same commit and is verified in the
-- board checkout — there is no product landing to prove.
local check = require("cosmic.check")
local flow = require("_work.commit_flow_fixture")
local done = require("_work.gitdone")
local gittake = require("_work.gittake")
local item = require("_work.item")
local store = require("_work.store")
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
test_research_completes_with_its_board_commit_landed()

local function test_a_landing_other_than_the_result_is_refused()
  local s, id, p = accepted_research("done-research-other")
  assert(done.cmd_done(s, id, "completed", false, "", "", p.next_head,
      p.root, flow.LANDER) ~= 0,
    "a product commit does not land a research item")
  local it = check.must(store.load(s, id))
  assert((it.resolution or "") == "" and (it.landed_head or "") == "")
end
test_a_landing_other_than_the_result_is_refused()

local function test_accepted_research_requires_a_landed_commit()
  local s, id, p = accepted_research("done-research-required")
  assert(done.cmd_done(s, id, "completed", false, "", "", "",
      p.root, flow.LANDER) ~= 0)
  assert((check.must(store.load(s, id)).resolution or "") == "")
end
test_accepted_research_requires_a_landed_commit()
