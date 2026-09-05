--- The one answer to "what should I do now": a pure function from the
--- board database's own `queue` view (plus the spec sidecars) to a
--- single action. The rows are `_work.read`'s; this module is only the
--- decision — the policy that consults them — split so growing one
--- never crowds the other against the file-length cap.
---
--- There is ONE worker and one ordering. Work flows right to left —
--- whatever is closest to completion moves first, because finishing
--- beats starting — so an accepted PR is merged before a verdict is
--- written, a verdict before a build is finished, and finishing
--- before pulling. Only then does anything new enter, and those rungs
--- are `_work.intake`: triage, refinement, and decomposition.
---
--- Doing SEVERAL actions is running this again after each one. The
--- board moved, so the answer may have moved with it: nothing here
--- plans a batch, and a caller that wants five actions asks five
--- times.
---
--- Which is why every action this returns must be one the verb gates
--- would ACCEPT: a pull is offered only under the doing bound and
--- only for items that pass the spec bar, or asking again would
--- return the same refused answer forever. When nothing in flight is
--- this session's to move and nothing passes, the ordering falls
--- through to the intake half — triage and refinement are real work
--- and no gate refuses them — and if that is empty too, the answer is
--- `none` with the binding fact named.
---
--- Every queue this reads orders by rank path with age as the last
--- word (`gitboard help order`), so "the next todo item" is really
--- "the highest-ranked one, oldest among equals" — `_work.read.queue`'s
--- own order, with the seeded per-session tie-break applied here: rows
--- tied on stage and on their key up to the first UNPOSITIONED field
--- (the view's own order otherwise) reorder by a hash of the seed and
--- the item's id, so concurrent sessions fan out across a tie no
--- judgment separates instead of converging on the same one.
---
--- A claim is a LOCK, and this is where that means something twice
--- over: a session that names itself is never handed work another
--- session's live claim holds, and never handed a diff another
--- session's live review claim is reading. Neither skip applies to a
--- session that names nothing: it has nobody to collide with, so it
--- is handed the claimed item anyway rather than stepped past it.
local decision = require("_work.decision")
local flow = require("_work.flow")
local gate = require("_work.gitgate")
local health = require("_work.health")
local index = require("_work.index")
local intake = require("_work.intake")
local item = require("_work.item")
local read = require("_work.read")
local seed_mod = require("_work.seed")

local type Item = item.Item
local type Index = index.Index
local type Action = decision.Action
local type Specs = intake.Specs

--- Whether a doing item is this session's to finish: unclaimed, its
--- own, or under a claim gone stale. A live foreign claim is a
--- builder mid loop on a machine the board cannot see.
--- @param i Item The item
--- @param session string This session's name, "" when unnamed
--- @param ages health.Ages Stale claim ages, by id (`_work.read.stale`,
--- split by `_work.health.from_rows`)
--- @return boolean True when this session may act on it
local function is_mine(i: Item, session: string, ages: health.Ages): boolean
  if (i.claim or "") == "" or session == "" or i.claim == session then
    return true
  end
  return health.is_stale(i, ages)
end

--- What the in-flight half decided, and what it stepped over on the
--- way. The counts ride on the record rather than in further return
--- slots: an absent `action` is the interesting case, and a caller
--- cannot read past slot two.
local record Phased
  --- The decision, absent when nothing in flight is this session's.
  action: Action
  --- Items held by other sessions' live claims.
  held: integer
  --- Items under another session's live review claim.
  reviewing: integer
  --- Accepted items already queued to merge, never a head to finish.
  queued: integer
  --- Pullable items the saturated doing bound refused to offer: the
  --- bound must name itself, or the stall reads as an empty queue.
  suppressed: integer
  --- Reviewable diffs stepped over because CI on the head has not
  --- settled — offering one would hand a reader a verdict it cannot
  --- yet give.
  ci_running: integer
  --- Reviewable diffs stepped over because CI on the head already
  --- failed — the fix is the builder's move, not a review.
  ci_red: integer
  --- One label per item counted in `ci_running`/`ci_red`, comma-joined
  --- in the order the loop met them — built from the exact same items
  --- the counters tallied, so a caller can never print a count and a
  --- name list that disagree.
  ci_names: string
end

--- CI check-run state by item id ("green" | "red" | "running" |
--- "none"), read once per render (`_work.gh`'s `head_checks`) the same
--- way `ages` is. An id absent from the map is exactly what a store
--- with no GitHub reach — no origin, no token, a read that failed —
--- reads back as, and `phased_action` treats it the way it always
--- has: offered, never held back.
local type CiStates = {string: string}

--- Whether an accepted item's PR reports already queued to merge
--- (`_work.review.is_queued`) — the same shape `ci` is; absent offers.
local type QueueStates = {string: boolean}

--- How many candidates one ask hands out, the primary included.
--- Sized to the concurrent-session count observed in practice: past
--- it the list is stale before anyone reaches its tail.
local CANDIDATES < const >: integer = 4

--- The doing items another session's live claim holds, as one
--- readable list ("3I3z2gOF @claude-scheduled"). Built only for the
--- terminal reason that reports them.
--- @param doing {Item} The doing queue
--- @param session string This session's name, "" when unnamed
--- @param ages health.Ages Stale claim ages, by id
--- @return string The held items, empty when none are
local function held_names(doing: {Item}, session: string,
    ages: health.Ages): string
  local out: {string} = {}
  for _, i in ipairs(doing) do
    if not is_mine(i, session, ages) then
      out[#out + 1] = ("%s @%s"):format(i.id:sub(1, 8), i.claim)
    end
  end
  return table.concat(out, ", ")
end

--- Whether a todo item passes the pure half of the spec bar: ranked,
--- spec sections filled. The take gate asks more (the chain traces);
--- this is the half a pure walk can answer, and a candidate the gate
--- still refuses surfaces as one refused take, not a loop.
--- @param c Index An index with `_work.readddl.ensure_views` applied
--- @param i Item The item
--- @param specs Specs Spec sidecar body, by item id
--- @return boolean True when the item may be offered as a pull
--- @return string Error message
local function passes_bar(c: Index, i: Item, specs: Specs): boolean, string
  local ranked, err = read.is_ranked(c, i.id)
  if ranked == nil then
    return false, err
  end
  if not ranked then
    return false, ""
  end
  return #flow.ready_gaps(specs[i.id] or "") == 0, ""
end

--- The decision over the ONE queue (`_work.read.queue`, tie-broken):
--- walk it head to tail, offering what this session can act on at
--- each stage — merge, review, finish, repair, pull — so rung order
--- is the queue's stage order rather than a second statement of it.
--- The decision is a LIST: the best action first and up to
--- `CANDIDATES` more behind it, so a session that loses the claim race
--- on the first has somewhere to go without another round trip.
--- @param c Index An index with `_work.readddl.ensure_views` applied
--- @param items {Item} All items
--- @param specs Specs Spec sidecar body, by item id
--- @param session string This session's name, "" when unnamed
--- @param ages health.Ages Stale claim/review ages, by id — the CLAIM
--- half for `is_mine`, the REVIEW half for the review-stale skip
--- @param review_ages health.Ages Stale REVIEW ages, by id
--- @param seed string Per-session tie-break seed, "" for age order
--- @param ci CiStates CI state by item id, absent when unknown
--- @param merge_queue QueueStates Accepted items already queued to merge
--- @return Phased | nil The decision and what it stepped over
--- @return string Error message
local function phased_action(c: Index, items: {Item}, specs: Specs,
    session: string, ages: health.Ages, review_ages: health.Ages,
    seed: string, ci?: CiStates, merge_queue?: QueueStates): Phased | nil, string
  local cim = ci or {}
  local qm = merge_queue or {}
  local rows, qerr = read.queue(c)
  if rows == nil then
    return nil, qerr
  end
  rows = seed_mod.tie_break(rows, seed)
  local by_id = item.by_id(items)
  local doing_n, dnerr = read.doing_count(c)
  if doing_n == nil then
    return nil, dnerr
  end
  local room = flow.DOING_LIMIT - doing_n
  local acts: {Action} = {}
  local held = 0
  local reviewing = 0
  local queued = 0
  local suppressed = 0
  local ci_running = 0
  local ci_red = 0
  local ci_blocked: {string} = {}
  -- Ordinary pulls are capped by the room the doing bound leaves and
  -- by the candidate slots the finishing stages left behind, computed
  -- at the first ordinary todo item — the queue's stage order
  -- guarantees every earlier stage has claimed its slots by then.
  local cap = -1
  for _, row in ipairs(rows) do
    local i = by_id[row.id]
    if i ~= nil then
      local stage = row.stage
      if stage == flow.STAGE_ACCEPTED then
        if qm[i.id] then
          -- Already merging on its own: never a blocker hold, or the
          -- terminal answer would misname it "resolve the blockers".
          queued = queued + 1
        elseif #acts < CANDIDATES then
          -- A handover has no PR to merge — `done` skips that read when
          -- `pr` is 0 — so its accepted reason names the verb that
          -- actually ends it rather than a merge it will never await.
          local reason = ("%s is accepted, awaiting merge — finishing beats "
            .. "starting"):format(i.id:sub(1, 8))
          if (i.result or "") ~= "" then
            reason = ("%s is accepted — `done ID` ends it"):format(
              i.id:sub(1, 8))
          end
          acts[#acts + 1] = {
            kind = "finish",
            item = i,
            reason = reason,
          }
        end
      elseif stage == flow.STAGE_REVIEW then
        if gate.distance_refusal(i, session) ~= nil then
          -- session built or specced this item — the same distance
          -- `take` refuses, so `next` never offers it either: offered
          -- to nobody here, and not another session's hold.
        elseif cim[i.id] == "running" then
          -- Not yet known either way: offering it hands a reader a
          -- verdict CI has not settled, exactly what `take`'s own CI
          -- gate refuses at claim time.
          ci_running = ci_running + 1
          ci_blocked[#ci_blocked + 1] = ("%s ci running"):format(
            i.id:sub(1, 8))
        elseif cim[i.id] == "red" then
          -- Already decided, but the move is the builder's: a fix and a
          -- new push, not a reviewer's time.
          ci_red = ci_red + 1
          ci_blocked[#ci_blocked + 1] = ("%s ci red — builder's"):format(
            i.id:sub(1, 8))
        elseif (i.reviewer or "") ~= "" and session ~= ""
        and i.reviewer ~= session
        and review_ages[i.id] == nil then
          reviewing = reviewing + 1
        elseif #acts < CANDIDATES then
          -- What awaits the verdict is a diff or a spec, never both
          -- (`item.problems`), and the reason names which so the
          -- reviewer reaches for the right one.
          local awaiting = "a PR"
          if (i.result or "") ~= "" then
            awaiting = "a research handover"
          end
          acts[#acts + 1] = {
            kind = "review",
            item = i,
            reason = ("%s awaits a verdict — verdicts before new work"):format(
              awaiting),
          }
        end
      elseif stage == flow.STAGE_REWORK or stage == flow.STAGE_BUILDING then
        if not is_mine(i, session, ages) then
          held = held + 1
        elseif #acts < CANDIDATES then
          local whose = ""
          if session ~= "" and (i.claim or "") ~= "" and i.claim ~= session then
            whose = (" (claim stale %dh — take it over: `take ID`, on the "
              .. "record)"):format(math.floor((ages[i.id] or 0) / 3600))
          elseif (i.claim or "") ~= "" then
            whose = (" (claimed by %s)"):format(i.claim)
          end
          local sub = "building"
          if stage == flow.STAGE_REWORK then
            sub = "rework"
          end
          acts[#acts + 1] = {
            kind = "finish",
            item = i,
            reason = ("%s is %s — finish before pulling%s"):format(
              i.id:sub(1, 8), sub, whose),
          }
        end
      else
        -- STAGE_REPAIR or STAGE_TODO: the spec bar gates both.
        local pb, pberr = passes_bar(c, i, specs)
        if pberr ~= "" then
          return nil, pberr
        end
        if not pb then
          -- A todo item below the bar is refinement's to answer, and the
          -- intake half owns that; the queue steps past it silently.
        elseif stage == flow.STAGE_REPAIR then
          -- A red lane's repair is the pull that cannot wait: never
          -- capped by the doing bound — the same lane bypass the take
          -- gate holds (`_work.read.doing_count`, over the SAME rows a
          -- `doing_refusal` check compares against `DOING_LIMIT`).
          if #acts < CANDIDATES then
            acts[#acts + 1] = {
              kind = "pull",
              item = i,
              reason = ("lane repair: %s"):format(i.key),
            }
          end
        elseif room <= 0 then
          -- The bound refused to offer anything: count what it withheld,
          -- so the terminal answer names the bound, not an empty queue.
          suppressed = suppressed + 1
        else
          if cap < 0 then
            cap = math.min(room, math.max(CANDIDATES - #acts, 0))
          end
          if cap > 0 then
            acts[#acts + 1] = {
              kind = "pull",
              item = i,
              reason = "highest-ranked todo item passing the spec bar",
            }
            cap = cap - 1
          end
        end
      end
    end
  end
  if #acts > 0 then
    local primary = acts[1]
    if #acts > 1 then
      local alts: {Action} = {}
      for k = 2, #acts do
        alts[#alts + 1] = acts[k]
      end
      primary.alternates = alts
    end
    return {action = primary, held = held, reviewing = reviewing,
      queued = queued, suppressed = suppressed,
      ci_running = ci_running, ci_red = ci_red,
      ci_names = table.concat(ci_blocked, ", ")}, ""
  end
  return {held = held, reviewing = reviewing, queued = queued,
    suppressed = suppressed,
    ci_running = ci_running, ci_red = ci_red,
    ci_names = table.concat(ci_blocked, ", ")}, ""
end

--- The one action to take now, right to left. Ages are optional the
--- way the session is: a caller without git in reach (the pure tests)
--- omits them, and the lease reporting stands down rather than
--- guessing.
--- @param c Index An index with `_work.readddl.ensure_views` applied
--- @param items {Item} All items
--- @param specs Specs Spec sidecar body, by item id
--- @param session string This session's name, "" when unnamed
--- @param ages health.Ages Stale claim ages, by id
--- @param review_ages health.Ages Stale review ages, by id
--- @param seed string Per-session tie-break seed, "" for age order
--- @param ci CiStates CI state by item id, absent when unknown
--- @param merge_queue QueueStates Accepted items already queued to merge
--- @return Action | nil The decision
--- @return string Error message
local function next_action(c: Index, items: {Item}, specs: Specs,
    session?: string, ages?: health.Ages, review_ages?: health.Ages,
    seed?: string, ci?: CiStates, merge_queue?: QueueStates): Action | nil, string
  local who = session or ""
  local aged = ages or {}
  local raged = review_ages or {}
  local salt = seed or ""
  local cim = ci or {}
  local qm = merge_queue or {}
  local ph, pherr = phased_action(c, items, specs, who, aged, raged, salt, cim, qm)
  if ph == nil then
    return nil, pherr
  end
  local phased = ph.action
  if phased then
    return phased, ""
  end
  -- Pullable work the saturated bound withheld outranks intake
  -- advice: the honest answer is the bound, named — a session sent
  -- to decompose while ten builds are in flight and work waits at
  -- the gate would only deepen what cannot enter.
  if ph.suppressed > 0 then
    local n, nerr = read.doing_count(c)
    if n == nil then
      return nil, nerr
    end
    return {
      kind = "none",
      reason = ("doing is at %d/%d and %d pullable item(s) wait — the "
        .. "bound throttles starting; nothing here is yours until "
        .. "something in flight finishes"):format(
        n, flow.DOING_LIMIT, ph.suppressed),
    }, ""
  end
  local taking, ierr = intake.intake_action(c, items, specs)
  if ierr ~= "" then
    return nil, ierr
  end
  if taking then
    return taking, ""
  end
  -- Nothing from anyone lands a queued accept, but naming it beats a
  -- generic "nothing here" once intake has nothing left either.
  if ph.queued > 0 then
    return {
      kind = "none",
      reason = ("%d accepted item(s) are queued to merge — GitHub lands "
        .. "them without a session's help"):format(ph.queued),
    }, ""
  end
  if ph.reviewing > 0 then
    return {
      kind = "none",
      reason = ("nothing here is this session's to move: %d item(s) are "
        .. "under another session's live review — their verdicts land "
        .. "elsewhere"):format(ph.reviewing),
    }, ""
  end
  -- CI running or already red outranks nothing new: the diff is real
  -- work in flight, just not a review anyone can act on yet — running
  -- because there is nothing to judge, red because the next move is
  -- the builder's, not a reviewer's.
  if ph.ci_running > 0 or ph.ci_red > 0 then
    return {
      kind = "none",
      reason = ("%d item(s) await CI before a review is worth claiming: %s")
      :format(ph.ci_running + ph.ci_red, ph.ci_names),
    }, ""
  end
  if ph.held > 0 then
    local doing: {Item} = {}
    for _, i in ipairs(items) do
      if item.is_open(i) and ((i.claim or "") ~= "" or (i.pr or 0) ~= 0) then
        doing[#doing + 1] = i
      end
    end
    return {
      kind = "none",
      reason = ("%d item(s) are other sessions' live claims and nothing "
        .. "else fires: %s — a claim past its lease is anyone's again")
      :format(ph.held, held_names(doing, who, aged)),
    }, ""
  end
  return {
    kind = "none",
    reason = "nothing in flight, nothing passing the spec bar, and "
    .. "nothing to triage, refine, or decompose",
  }, ""
end

local record action
  type Action = Action
  type Phased = Phased
  type Specs = Specs
  type CiStates = CiStates
  type QueueStates = QueueStates
  passes_bar: function(c: Index, i: Item, specs: Specs): boolean, string
  phased_action: function(c: Index, items: {Item}, specs: Specs,
  session: string, ages: health.Ages, review_ages: health.Ages,
  seed: string, ci?: CiStates, merge_queue?: QueueStates): Phased | nil, string
  next_action: function(c: Index, items: {Item}, specs: Specs,
  session?: string, ages?: health.Ages, review_ages?: health.Ages, seed?: string,
  ci?: CiStates, merge_queue?: QueueStates): Action | nil, string
end

local M: action = {
  passes_bar = passes_bar,
  phased_action = phased_action,
  next_action = next_action,
}

return M
