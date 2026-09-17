#!/usr/bin/env cosmic
-- Acceptance-model guidance has its own seam: the existing renderer
-- snapshots are at the 500-line cap. Exercise rendered briefs, not source.
local briefcommands = require("_work.briefcommands")
local briefcontext = require("_work.briefcontext")
local doctrine = require("_work.doctrine")

local function facts(): briefcontext.Facts
  return {
    repo = "cosmic-lua/work", worktree = "/wt/review", product_root = "/src/work",
    head_sha = "0123456789abcdef", review_target = "fedcba9876543210",
    board_dir = "/src/work/o/board", item_id = "acceptance", handle = "test",
    title = "Guard the requested outcome", review_session = "independent-review",
    change_source = "Immutable handover", round_context = "",
    spec = "## Problem\nOriginal starting state\n## Change\n{{.opaque}}\n## Non-goals\nBounded fix\n",
  }
end

local function commands(): briefcommands.Commands
  return {test_cmd_phrase = "`test <file>`", bootstrap_phrase = "Bootstrap first."}
end

local function flat(body: string): string
  return (body:gsub("%s+", " "))
end

local function test_code_review_challenges_acceptance_before_mutation()
  local f = facts()
  local full = briefcontext.review(f, commands())
  local mechanical = briefcontext.review_script(f, commands())
  for _, body in ipairs({full, mechanical}) do
    local text = flat(body)
    local before = assert(text:find("before reading the builder's test rationale", 1, true),
      "acceptance case must precede the builder's test rationale")
    local mutation = assert(text:find("Mutation-test at least one guard", 1, true))
    assert(before < mutation, "acceptance modeling precedes the existing mutation step")
    for _, wanted in ipairs({"derive a plausible failure", "supplied problem, full spec and parent outcome",
        "fixtures, setup steps, exclusions and assertions", "material parent context",
        "one focused discriminating check", "reported scenario is covered or remains unresolved",
        "requested outcome and within the permitted correction boundary",
        "Mutating an existing assertion alone does not challenge its acceptance model",
        "Keep relevant evidence available", "No extra round, full gate or second mutation is mandatory",
        "pure rename or pin-only change requires no invented counterexample"}) do
      assert(text:find(wanted, 1, true), "acceptance-model requirement missing: " .. wanted)
    end
    assert(body:find(f.spec or "missing", 1, true), "full spec must remain verbatim")
    assert(text:find("Review `fedcba9876543210...0123456789abcdef`", 1, true),
      "acceptance review preserves immutable commit identities")
    assert(text:find("never substitute a branch tip or provider state for either commit", 1, true))
  end
  assert(flat(mechanical):find("When this changes a behavioral guard", 1, true),
    "mechanical acceptance work is proportional to behavioral effect")
end

local function test_research_keeps_evidence_reproduction()
  local f = facts()
  f.findings = "Measured claim at immutable commit; command and result."
  local body = briefcontext.review(f, commands())
  local text = flat(body)
  assert(text:find("Every measured claim names its command, and the command reproduces", 1, true))
  assert(text:find("There is no guard to mutation-test", 1, true))
  assert(not text:find("derive a plausible failure", 1, true),
    "research retains evidence reproduction rather than code acceptance modeling")
  assert(body:find(f.findings, 1, true) and body:find(f.spec or "missing", 1, true))
end

local function test_review_doctrine_aligns_acceptance_and_exceptions()
  local text = flat(assert(doctrine.page("review")))
  for _, wanted in ipairs({"before reading the builder's test rationale",
      "fixtures, setup steps, exclusions and assertions", "one focused discriminating check",
      "reported scenario is covered or remains unresolved", "bounded correction scope",
      "mechanical changes to a behavioral guard", "pure renames and pin-only changes",
      "Mutating an existing assertion alone is insufficient", "no extra round, full gate or mandatory second mutation",
      "Research review retains its measured-claim evidence reproduction", "Keep relevant evidence available",
      "full spec, immutable review range"}) do
    assert(text:find(wanted, 1, true), "review doctrine missing: " .. wanted)
  end
end
