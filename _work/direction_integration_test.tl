#!/usr/bin/env cosmic
local check = require("cosmic.check")
local flow = require("_work.commit_flow_fixture")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local graph = require("_work.gitgraph")
local show = require("_work.gitshow")
local spec = require("_work.spec")
local store = require("_work.store")
local doctrine_bar = require("_work.doctrine_bar")

local function capture(run: function(): integer): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, result = pcall(run)
  _G.print = old_print
  if not ok then error(result, 0) end
  return result, table.concat(lines, "\n")
end

local function test_advisories_file_show_and_claim_normally()
  local s = fixture.init_state_repo("direction-advisory")
  local root, _leaf = fixture.root_with_leaf(s)
  local prose = {change = "Update all callers. The caller has it.\n",
    non_goals = "No other change.\n"}
  local code, out = capture(function(): integer
      return graph.cmd_new(s, "direction advisory slice", root, prose, "acme/widgets")
    end)
  assert(code == 0, "advisories cannot block filing: " .. out)
  assert(out:find('direction-advisory: "all callers"', 1, true) ~= nil,
    "new prints the quantifier advisory: " .. out)
  assert(out:find('direction-advisory: "the caller has it"', 1, true) ~= nil,
    "new prints the existence advisory: " .. out)
  local id = ""
  for _, it in ipairs(check.must(store.list(s))) do
    if it.title == "direction advisory slice" then id = it.id end
  end
  assert(id ~= "", "warned item was filed")
  fixture.caller_publish(s)
  local shown, report = capture(function(): integer return show.cmd_show(s, id) end)
  assert(shown == 0)
  assert(report:find('direction-advisory: "all callers"', 1, true) ~= nil,
    "ordinary show prints the quantifier advisory: " .. report)
  assert(report:find('direction-advisory: "the caller has it"', 1, true) ~= nil,
    "ordinary show prints the existence advisory: " .. report)
  assert(report:find("bar:", 1, true) == nil
    and report:find("flagged:", 1, true) == nil,
    "direction hints are separate from admission problems: " .. report)

  local path = fs.join(fixture.tmpdir, "direction-raw-show")
  local old_stdout = io.stdout
  local output = assert(io.open(path, "w"))
  io.stdout = output
  local ok, raw_code = pcall(show.cmd_show, s, id, true)
  output:flush()
  output:close()
  io.stdout = old_stdout
  if not ok then error(raw_code, 0) end
  assert(raw_code == 0)
  assert(assert(fs.read(path)) == spec.document(store.read_spec(s, id)),
    "raw show remains byte-exact with warning phrases")
  assert(flow.claim(s, id, flow.BUILDER, flow.product("direction-advisory")) == 0,
    "warned item passes actual claim admission")
  assert(check.must(store.load(s, id)).claim == flow.BUILDER)
end

local function test_help_preserves_direction_without_measurement()
  local text = doctrine_bar.BODY:gsub("%s+", " ")
  assert(text:find("name a set/source pointer", 1, true) ~= nil)
  assert(text:find("Builders enumerate and verify against the current tree", 1, true) ~= nil)
  assert(text:find("Refinement requires no inventories, counts, pasted commands/output or line citations", 1, true) ~= nil)
  assert(text:find("silence does not certify completeness", 1, true) ~= nil)
  assert(text:find("Hints are advisory only", 1, true) ~= nil)
end
