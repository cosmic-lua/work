#!/usr/bin/env cosmic
-- UNITS is the membership authority. Classifications below add obligations,
-- never enumerate templates to test: a new unit must earn a classification.
-- Exercise the production context composers used by brief.tl, with neutral
-- item data so quoted specs/findings cannot supply or contradict policy.
local source = require("_work.brieftmpl_source")
local context = require("_work.briefcontext")
local commands = require("_work.briefcommands")
local brieftext = require("_work.brieftext")
local friction = require("_work.brieftext_friction")

local record Policy
  shape: string
  mutation: string
  board: string
  gate: string
  consumers: {string}
end

-- Each exemption names why; fragments inherit each consumer's obligations.
local function classify(name: string): Policy | nil, string
  if name == "builder" then
    return {shape = "whole", mutation = "required", board = "caller", gate = "full",
      consumers = {"builder", "builder_rework"}}, ""
  elseif name == "research" then
    return {shape = "whole", mutation = "exempt: evidence only", board = "caller",
      gate = "exempt: probes only", consumers = {"research", "research_rework"}}, ""
  elseif name == "refine" then
    return {shape = "whole", mutation = "exempt: spec drafting", board = "caller",
      gate = "exempt: no code change", consumers = {"refine"}}, ""
  elseif name == "decompose" then
    return {shape = "whole", mutation = "exempt: child drafting", board = "caller",
      gate = "exempt: no code change", consumers = {"decompose"}}, ""
  elseif name == "review_script" then
    return {shape = "whole", mutation = "required", board = "caller",
      gate = "exempt: focused review", consumers = {"review_script"}}, ""
  elseif name == "review" then
    return {shape = "whole", mutation = "consumer", board = "caller", gate = "consumer",
      consumers = {"review_diff", "review_research"}}, ""
  elseif name == "rework" then
    return {shape = "fragment", mutation = "consumer", board = "caller", gate = "consumer",
      consumers = {"builder_rework", "research_rework"}}, ""
  elseif name == "opening_diff" then
    return {shape = "fragment", mutation = "required", board = "caller",
      gate = "exempt: focused review", consumers = {"review_diff"}}, ""
  elseif name == "reviewing_diff" then
    return {shape = "fragment", mutation = "required", board = "caller",
      gate = "exempt: focused review", consumers = {"review_diff"}}, ""
  elseif name == "posture_diff" then
    return {shape = "fragment", mutation = "required", board = "caller",
      gate = "exempt: focused review", consumers = {"review_diff"}}, ""
  elseif name == "opening_research" then
    return {shape = "fragment", mutation = "exempt: findings review", board = "caller",
      gate = "exempt: reproduction probes", consumers = {"review_research"}}, ""
  elseif name == "reviewing_research" then
    return {shape = "fragment", mutation = "exempt: findings review", board = "caller",
      gate = "exempt: reproduction probes", consumers = {"review_research"}}, ""
  elseif name == "posture_research" then
    return {shape = "fragment", mutation = "exempt: findings review", board = "caller",
      gate = "exempt: reproduction probes", consumers = {"review_research"}}, ""
  elseif name == "round" then
    -- brief.tl always supplies round_context=""; do not invent a review round.
    return {shape = "inactive fragment", mutation = "exempt: no current consumer",
      board = "exempt: no current consumer", gate = "exempt: no current consumer",
      consumers = {}}, ""
  end
  return nil, "unclassified unit"
end

local function facts(): context.Facts
  return {repo = "example/product", worktree = "/example/work", branch = "work/example",
    product_root = "/example/product", board_dir = "/example/board",
    item_id = "item-contract", handle = "contract", title = "Neutral task",
    spec = "## Change\nA neutral task.", current_spec = "## Change\nA neutral task.",
    preparation = brieftext.BUILDER_PREPARATION, bounce_context = "",
    head_sha = "head-contract", review_session = "session-contract", round_context = "",
    claim_base = "base-contract", review_target = "base-contract", change_source = "",
    gitboard_cmd = "CALLER_INVOCATION_MUST_NOT_RENDER"}
end

local function rendered(): {string: string}
  local f = facts()
  local cmds = commands.commands("", "builder")
  local bodies: {string: string} = {}
  bodies.builder = context.builder(f, cmds)
  bodies.research = context.research(f)
  bodies.refine = context.refine(f)
  bodies.decompose = context.decompose(f)
  f.bounce_context = context.rework("judged-contract", "work/example")
  bodies.builder_rework = context.builder(f, cmds)
  bodies.research_rework = context.research(f)
  f.bounce_context = ""
  cmds = commands.commands("", "review")
  bodies.review_script = context.review_script(f, cmds)
  bodies.review_diff = context.review(f, cmds)
  f.findings = "Neutral measured findings."
  bodies.review_research = context.review(f, cmds)
  for name, body in pairs(bodies) do
    bodies[name] = (body .. "\n\n" .. friction.ASK):gsub("%s+", " ")
  end
  return bodies
end

local function has(body: string, needle: string): boolean
  return body:find(needle, 1, true) ~= nil
end

local function require_text(role: string, body: string, needle: string)
  assert(has(body, needle), role .. " missing workflow guidance: " .. needle)
end

local function mutation_contract(role: string, body: string, mode: string)
  if mode:match("^exempt:") then
    assert(not has(body, "Mutation-test at least one"), role .. " must remain mutation-exempt")
    return
  end
  require_text(role, body, "For generated code, mutate the SOURCE, never the artifact")
  require_text(role, body, "A green build that regenerated away the mutation is INCONCLUSIVE")
  require_text(role, body, "the named test assertion actually fails")
  require_text(role, body, "a generator/build refusal does not count")
end

local function board_contract(role: string, body: string)
  assert(not has(body, "CALLER_INVOCATION_MUST_NOT_RENDER"), role .. " renders caller invocation")
  if role:match("^builder") then
    require_text(role, body, "Do NOT run any `gitboard` command")
    require_text(role, body, "so it can fetch/push it and run `take item-contract --head SHA [--url URL]` itself")
  elseif role:match("^review") then
    require_text(role, body, "You do not run `verdict`")
    require_text(role, body, "The caller records your verdict")
    require_text(role, body, "the caller runs")
    require_text(role, body, "verdict: accept|request-changes|reject head=head-contract session=session-contract")
  elseif role:match("^research") then
    require_text(role, body, "board state is the orchestrator's job")
    require_text(role, body, "never run a `gitboard` command yourself")
  else
    require_text(role, body, "The caller runs all board commands")
    require_text(role, body, "Never run a `gitboard` command yourself")
  end
end

local function gate_contract(role: string, body: string, mode: string)
  if mode == "full" then
    require_text(role, body, "The full gate already runs coverage: run it once after your last test edit, never a separate coverage stage")
    require_text(role, body, "Run the repo's gate locally and confirm it is green")
    require_text(role, body, "a new test moves a row's `total`")
  end
  -- Review/probe exemptions do not authorize a separate coverage requirement.
  assert(not has(body, "--make coverage"), role .. " must not require a separate coverage stage")
end

local function no_conflicts(role: string, body: string)
  -- Bounded historical/tempting counterinstructions, not a prose classifier.
  for _, forbidden in ipairs({"mutate the artifact", "mutate the generated output",
      "a generator/build refusal counts", "regenerated away the mutation is conclusive",
      "run coverage separately", "run a separate coverage stage",
      "refresh` before you write", "File each with:",
      "Write the new spec to a file holding ONLY the spec, then:",
      "run `bin/gitboard help bar`", "Run `bin/gitboard help bar`",
      "Run `gitboard take", "Run `gitboard verdict", "Run `gitboard spec",
      "run `take item-contract", "run `verdict item-contract"}) do
    -- Builder's caller-attributed take sentence is a legitimate example.
    if forbidden ~= "run `take item-contract" or not role:match("^builder") then
      assert(not has(body, forbidden), role .. " conflicting workflow instruction: " .. forbidden)
    end
  end
end

local function test_every_registered_unit_has_an_explicit_policy()
  for _, unit in ipairs(source.UNITS) do
    local policy = classify(unit.name)
    assert(policy ~= nil, "unclassified workflow unit: " .. unit.name)
    assert(policy.shape ~= "" and policy.mutation ~= "" and policy.board ~= ""
      and policy.gate ~= "", "incomplete workflow classification: " .. unit.name)
    assert(#policy.consumers > 0 or policy.shape == "inactive fragment",
      "active workflow unit has no consumer: " .. unit.name)
  end
end

local function test_complete_rendered_roles_obey_workflow_rules()
  local bodies = rendered()
  local checked: {string: boolean} = {}
  for _, unit in ipairs(source.UNITS) do
    local policy = assert(classify(unit.name), "unclassified workflow unit: " .. unit.name)
    for _, role in ipairs(policy.consumers) do
      local body = assert(bodies[role], "missing rendered consumer: " .. role)
      local mutation, gate = policy.mutation, policy.gate
      if mutation == "consumer" then
        mutation = (role:match("^builder") or role == "review_diff")
        and "required" or "exempt: evidence only"
      end
      if gate == "consumer" then
        gate = role:match("^builder") and "full" or "exempt: no changed code"
      end
      mutation_contract(role, body, mutation)
      board_contract(role, body)
      gate_contract(role, body, gate)
      no_conflicts(role, body)
      checked[role] = true
    end
  end
  for role, _ in pairs(bodies) do
    assert(checked[role], "rendered role has no registered unit: " .. role)
  end
end
