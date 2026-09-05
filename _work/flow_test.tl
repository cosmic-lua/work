#!/usr/bin/env cosmic
-- What remains of `_work.flow` once every graph derivation moved into
-- the board database's views (`docs/design/read.md`): the one WIP
-- bound, the stage order's numeric constants, and the spec bar's gap
-- check. The derivations themselves — role, state, substate, stage,
-- the unified queue, the doing count, the triage and outcome queues,
-- graph health — are `_work/read_test.tl`'s to pin, over the views
-- that now answer them; what a session DOES with all this is
-- `_work/action_test.tl`.

local flow = require("_work.flow")

local function test_the_stage_order_runs_accepted_to_todo()
  assert(flow.STAGE_ACCEPTED < flow.STAGE_REVIEW, "accepted beats review")
  assert(flow.STAGE_REVIEW < flow.STAGE_REWORK, "review beats rework")
  assert(flow.STAGE_REWORK < flow.STAGE_BUILDING, "rework beats building")
  assert(flow.STAGE_BUILDING < flow.STAGE_REPAIR, "building beats a lane repair")
  assert(flow.STAGE_REPAIR < flow.STAGE_TODO, "a lane repair beats ordinary todo")
end

local function test_the_doing_bound_is_positive()
  assert(flow.DOING_LIMIT > 0, "there is a bound to hold in-flight work to")
end

-- `ready_gaps` is `_work.spec.ready_gaps`, unchanged — this module's
-- own re-export of it, pinned so a caller reaching it through
-- `flow.ready_gaps` gets the exact same answer `_work/spec_test.tl`
-- already pins in full.
local function test_ready_gaps_is_specs_own()
  assert(#flow.ready_gaps("") > 0, "an empty spec still misses the bar")
  assert(#flow.ready_gaps("## Change\nDo this.\n## Non-goals\nNot that.\n") == 0,
    "a spec with both required sections passes")
end
