#!/usr/bin/env cosmic
-- Compatibility boundaries after v3 removes provider-backed PR workflow.
-- Old entry points fail closed and pure navigation helpers remain side-effect
-- free; commit IDs are the only workflow evidence accepted by the live CLI.

local check = require("cosmic.check")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local gittake = require("_work.gittake")
local gitverdict = require("_work.gitverdict")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

local tmpdir = os.getenv("TEST_TMPDIR") or "/tmp"

local function test_legacy_pr_verdict_refuses_without_mutating_the_item()
  local s = fixture.init_state_repo("legacy-pr-verdict")
  local _parent, id = fixture.root_with_leaf(s)
  local before = check.must(store.load(s, id))
  assert(gitverdict.cmd_verdict(s, id, "accept", 42, "", "reviewer") ~= 0)
  local after = check.must(store.load(s, id))
  assert(after.verdict == before.verdict and after.verdict_head == ""
    and after.pr == 0, "the compatibility refusal records no provider fact")
end

local function test_legacy_open_refuses_without_authenticated_side_effects()
  local s = fixture.init_state_repo("legacy-open-plan")
  local _parent, id = fixture.root_with_leaf(s)
  local it = check.must(store.load(s, id))
  it.repo = "acme/widgets"
  it.claim = "0123456789abcdef0123456789abcdef"
  assert(storewrite.save(s, it, "fixture: claimed item with repository"))
  it = check.must(store.load(s, id))
  local before = check.must(store.load(s, id))
  assert(gittake.take_open(s, it, it.claim, 0, "") ~= 0,
    "the compatibility helper directs the caller to commit-only handover")
  local after = check.must(store.load(s, id))
  assert(after.pr == before.pr and after.handover_head == before.handover_head,
    "printing caller instructions performs no authenticated action or write")
end

local function test_open_body_is_navigation_text_not_evidence()
  local id = "3Ixb9PupZFNmdqcTV9w7zgthrqC"
  local body = check.must(gittake.open_body(id, ""))
  assert(body == "Board: " .. id)
  local path = fs.join(tmpdir, "gitverbs-pr-v3-body.md")
  assert(fs.write(path, "context for a human caller"))
  local extended = check.must(gittake.open_body(id, path))
  assert(extended == "Board: " .. id .. "\n\ncontext for a human caller")
end
