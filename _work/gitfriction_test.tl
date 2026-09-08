#!/usr/bin/env cosmic
-- Friction logs are ordinary board items. Opaque claim sessions deliberately
-- carry no semantic agent label, so `new` does not infer a roll call from
-- claim history or impose a special filing gate on a `friction:` title.

local check = require("cosmic.check")
local fixture = require("_work.fixture")
local graph = require("_work.gitgraph")
local store = require("_work.store")

local function test_friction_item_accepts_the_spec_the_caller_supplies()
  local s = fixture.init_state_repo("friction-ordinary-item")
  local before = check.must(store.list(s))
  local body = [[
## Workflow
The prepared transaction took more calls than expected.

## Language level
The record type made the intended boundary unclear.
]]
  assert(graph.cmd_new(s, "friction: offline claim pass", "", body, "") == 0,
    "a friction item needs no claim-derived roll call")
  local after = check.must(store.list(s))
  assert(#after == #before + 1)
  local filed = after[#after]
  assert(filed.title == "friction: offline claim pass")
  local saved = store.read_spec(s, filed.id)
  assert(saved:find("## Workflow", 1, true)
    and saved:find("## Language level", 1, true),
    "friction evidence remains ordinary caller-authored spec prose")
end
