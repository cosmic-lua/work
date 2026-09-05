--- What remains of the flow rules once every derivation over the item
--- graph moved into the board database's views (`_work.readddl`,
--- read back through `_work.read` — `docs/design/read.md`): the one
--- WIP bound, the stage order's numeric constants (the `stage` view
--- computes the same ranking; these name it for the Teal code that
--- still branches on a queue row's `stage` field), and the spec bar's
--- gap check, which reads a spec body alone and touches no graph.
---
---   board     the one parentless item — never workable, never taken
---   container any item with open children (being decomposed)
---   outcome   a direct child of the board — decomposed, never taken
---   work      a childless item below the outcome level
---
--- A workable item's STATE derives from the facts it carries, never
--- from a declared column:
---
---   todo    open, unclaimed, no PR — pullable once its spec passes
---           the bar (`_work.spec.ready_gaps`, asked at take)
---   doing   open with a claim or a PR; within it the same facts say
---           what happens next: building, review, rework, accepted —
---           or queued, when a caller has read the PR and found it
---           already merging on its own
---
--- ONE WIP bound, `DOING_LIMIT`, covers the whole in-flight span:
--- taking NEW work is refused at the limit, finishing motions never
--- are. Capacity otherwise spreads by worker — one claim per session
--- — so there is no per-column table and nothing to tune per phase.
---
--- Every queue orders by rank path; `gitboard help order` is the rule
--- (`_work.readddl`'s own header carries it verbatim).
---
--- What a session should DO with all this is `_work.action`: the
--- policy that reads the database and decides is a separate module,
--- so growing one never crowds the other against the file-length cap.
local spec = require("_work.spec")

--- The most open doing items the board holds before a new take is
--- refused. One number over the whole in-flight span (building,
--- awaiting review, rework, awaiting merge): claims and open PRs
--- outlive the sessions that made them, so with no bound a fleet of
--- come-and-go workers accumulates half-finished work faster than
--- reviews retire it. Inherits the envelope the retired per-phase
--- limits allowed in practice; re-tuned by measurement over the
--- board's own log, as a reviewed change here.
local DOING_LIMIT < const >: integer = 10

--- The stage half of the unified order: how close an item is to
--- done, lower ranks first. ONE declaration — every queue, offer,
--- and refusal that says "finishing beats starting" derives from
--- this ranking rather than restating it: accepted work merges
--- before verdicts land, verdicts before rework, rework before
--- builds, and only then does anything new start — a red lane's
--- repair first (the pull that cannot wait), ordinary todo last.
--- `_work.readddl`'s `stage` view computes the same numbers over the
--- database directly; these constants are what Teal code branches on
--- against a `_work.read.QueueRow.stage` field.
local STAGE_ACCEPTED < const >: integer = 1
local STAGE_REVIEW < const >: integer = 2
local STAGE_REWORK < const >: integer = 3
local STAGE_BUILDING < const >: integer = 4
local STAGE_REPAIR < const >: integer = 5
local STAGE_TODO < const >: integer = 6

local record flow
  DOING_LIMIT: integer
  STAGE_ACCEPTED: integer
  STAGE_REVIEW: integer
  STAGE_REWORK: integer
  STAGE_BUILDING: integer
  STAGE_REPAIR: integer
  STAGE_TODO: integer
  ready_gaps: function(body: string): {string}
end

local M: flow = {
  DOING_LIMIT = DOING_LIMIT,
  STAGE_ACCEPTED = STAGE_ACCEPTED,
  STAGE_REVIEW = STAGE_REVIEW,
  STAGE_REWORK = STAGE_REWORK,
  STAGE_BUILDING = STAGE_BUILDING,
  STAGE_REPAIR = STAGE_REPAIR,
  STAGE_TODO = STAGE_TODO,
  ready_gaps = spec.ready_gaps,
}

return M
