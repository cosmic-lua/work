#!/usr/bin/env cosmic
-- No brief renders a board command line: the reviewer reports the
-- verdict envelope and the builder a commit id, and the caller runs
-- `verdict`/`take` — so the caller's invocation field never reaches a
-- body, where an unresolved one renders as a sentinel no agent can run.
-- Pinned on the template SOURCE, one check per posture; the rendered
-- briefs are pinned the same way beside each posture's own test.

local brieftext = require("_work.brieftext")
local brieftext_review = require("_work.brieftext_review")

local ENVELOPE < const > = "verdict: accept|request-changes|reject "
.. "head={{.head_sha}} session={{.review_session}}"

local function test_no_posture_renders_a_verdict_or_take_command()
  for name, tmpl in pairs({builder = brieftext.BUILDER, rework = brieftext.REWORK,
      review = brieftext_review.REVIEW, script = brieftext_review.REVIEW_SCRIPT,
      diff = brieftext_review.POSTURE_DIFF,
      research = brieftext_review.POSTURE_RESEARCH}) do
    assert(tmpl:find("{{.gitboard_cmd}}", 1, true) == nil
      and tmpl:find("verdict {{.item_id}}", 1, true) == nil,
      name .. " must render neither the caller's invocation nor a verdict command")
  end
end

local function test_every_review_posture_asks_for_the_envelope()
  for name, tmpl in pairs({script = brieftext_review.REVIEW_SCRIPT,
      diff = brieftext_review.POSTURE_DIFF,
      research = brieftext_review.POSTURE_RESEARCH}) do
    assert(tmpl:find(ENVELOPE, 1, true) ~= nil,
      name .. " must ask for the verdict envelope instead")
    assert(tmpl:find("You do not run `verdict`", 1, true) ~= nil
      and tmpl:find("the caller runs", 1, true) ~= nil,
      name .. " must say the caller, not the reviewer, runs the board verbs")
  end
end
