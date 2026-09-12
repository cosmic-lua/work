#!/usr/bin/env cosmic
-- Friction logs are ordinary board items. Opaque claim sessions deliberately
-- carry no semantic agent label, so `new` does not infer a roll call from
-- claim history or impose a special filing gate on a `friction:` title.

local check = require("cosmic.check")
local fixture = require("_work.fixture")
local graph = require("_work.gitgraph")
local specmod = require("_work.spec")
local store = require("_work.store")

local function test_friction_item_accepts_the_spec_the_caller_supplies()
  local s = fixture.init_state_repo("friction-ordinary-item")
  local before = check.must(store.list(s))
  local before_ids: {string: boolean} = {}
  for _, it in ipairs(before) do before_ids[it.id] = true end
  -- Ordinary caller-authored prose, in the grammar the tree holds: a
  -- retrospective heading is refused by `spec.split` now (see
  -- `_work/spec_test.tl`), so the friction narrative is a log entry and
  -- what the item declares is what to do about it.
  local prose = check.must(specmod.split([[
## Change
The prepared transaction took more calls than expected, and the record
type made the intended boundary unclear. Cut both.
]]))
  assert(graph.cmd_new(s, "friction: offline claim pass", "", prose, "") == 0,
    "a friction item needs no claim-derived roll call")
  local after = check.must(store.list(s))
  assert(#after == #before + 1)
  -- Same-second KSUIDs sort by random payload, not filing order.
  local filed_id: string = nil
  for _, it in ipairs(after) do
    if not before_ids[it.id] then filed_id = it.id end
  end
  local filed = check.must(store.load(s, check.must(filed_id)))
  assert(filed.title == "friction: offline claim pass")
  local saved = store.read_spec(s, filed.id)
  assert(saved.change:find("prepared transaction", 1, true)
    and saved.change:find("intended boundary", 1, true),
    "friction evidence remains ordinary caller-authored spec prose")
end
