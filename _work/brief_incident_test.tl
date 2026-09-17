#!/usr/bin/env cosmic
-- Incident closure is a rendered handoff contract, including rework and
-- mechanically selected code review. Keep this focused sibling outside
-- brieftmpl_test.tl, which is already near the 500-line cap.
local briefcontext = require("_work.briefcontext")
local briefcommands = require("_work.briefcommands")
local doctrine = require("_work.doctrine")

local function flat(text: string): string
  return (text:gsub("%s+", " "))
end

local function contains(text: string, needle: string)
  assert(text:find(needle, 1, true) ~= nil,
    "incident guidance missing: " .. needle)
end

local function closure(text: string)
  contains(text, "the reported scenario")
  contains(text, "the reproduced condition, and the condition repaired")
  contains(text, "report the change as partial")
  contains(text, "ask the caller to retain the unresolved incident as explicit follow-up work")
  contains(text, "never silently discharge that scope")
  contains(text, "unavailable historical environment")
  contains(text, "useful bounded fix")
  contains(text, "no blanket regression requirement for nonbehavioral edits")
end

local function incident_example(text: string)
  contains(text, "Work PR194 followed by PR207")
  contains(text, "a fetched tracking-ref fixture does not model a never-fetched clone")
  contains(text, "whose local and tracking refs agree while both are stale")
end

local function test_builder_and_rework_preserve_the_reported_starting_state()
  local commands: briefcommands.Commands = {}
  for _, rework in ipairs({false, true}) do
    local facts: briefcontext.Facts = {spec = "## Change\nA bounded repair."}
    if rework then facts.bounce_context = briefcontext.rework("abc123", "work/fix") end
    local body = flat((briefcontext.builder(facts, commands)))
    closure(body)
    incident_example(body)
    contains(body, "Reproduce from the caller's starting state before setup can repair or hide the fault")
    contains(body, "carry that scenario into a regression")
    contains(body, "An unavailable historical environment is not itself a STOP")
    contains(body, "premise STOP below still applies to a contradicted premise of that fix")
    if rework then contains(body, "This is a rework, not a fresh pull") end
  end
end

local function test_both_code_review_postures_compare_fixture_with_incident()
  local facts: briefcontext.Facts = {}
  local commands: briefcommands.Commands = {}
  local full = briefcontext.review(facts, commands)
  local mechanical = briefcontext.review_script(facts, commands)
  for _, rendered in ipairs({full, mechanical}) do
    local body = flat(rendered)
    closure(body)
    incident_example(body)
    contains(body, "Compare the fixture setup with the reported incident")
    contains(body, "does setup repair or hide the fault before the test?")
    contains(body, "regression carries the caller's starting state")
    contains(body, "it does not prove incident closure")
  end
end

local function test_research_does_not_inherit_code_regression_duties()
  local facts: briefcontext.Facts = {findings = "A measured finding."}
  local commands: briefcommands.Commands = {}
  local builder = briefcontext.research(facts)
  local reviewer = briefcontext.review(facts, commands)
  for _, body in ipairs({builder, reviewer}) do
    assert(body:find("fixture setup", 1, true) == nil
      and body:find("carry that scenario into a regression", 1, true) == nil
      and body:find("Mutation-test at least one", 1, true) == nil,
      "research must not inherit code mutation or regression duties")
  end
end

local function test_build_and_review_doctrine_preserve_partial_scope()
  local build = flat(assert(doctrine.page("build")))
  contains(build, "the reproduced condition, and the condition repaired")
  contains(build, "caller's starting state before setup can repair or hide the fault")
  contains(build, "carry that scenario into a regression")
  contains(build, "scenario still unproven is partial")
  contains(build, "caller retain the unresolved incident as explicit follow-up work")
  contains(build, "unavailable historical environment need not block a useful bounded fix")
  contains(build, "no blanket regression requirement for nonbehavioral edits")
  local review = flat(assert(doctrine.page("review")))
  closure(review)
  incident_example(review)
  contains(review, "Compare the fixture setup with the reported incident")
end
