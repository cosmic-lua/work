--- Board health beyond per-item shape: the stalls `status` renders
--- and `next` must not answer around. Pure over already-read state,
--- the way `_work.flow` is — timestamps arrive from the caller, so
--- nothing here touches git or the filesystem. Two lease detectors:
---
---   stale claims    a claim is a lock with no expiry, held by
---                   sessions that are ephemeral by construction; a
---                   claimed item whose last board commit is older
---                   than the lease is stalled, not in progress
---   stale reviews   the review claim's shorter horizon, same idea
---
--- The board database's `stale` view (`_work.readddl`, read through
--- `_work.read.stale`) is where the walk over every item's
--- `touched_at` now happens — already filtered to claims and review
--- claims past their horizon, `LEASE_S`/`REVIEW_LEASE_S` below restated
--- as the view's own literal seconds. `from_rows` turns its rows back
--- into the two per-kind `Ages` maps `is_stale`/`is_review_stale` read.
local item = require("_work.item")
local read = require("_work.read")

local type Item = item.Item

--- Seconds since each item's last board commit, by id. Absent entries
--- mean unknown, and unknown never reads as stale.
local type Ages = {string: integer}

--- The two `Ages` maps a `_work.read.stale` call splits into, by kind.
local record StaleAges
  claim: Ages
  review: Ages
end

--- Split `_work.read.stale`'s rows into the two per-kind `Ages` maps
--- `is_stale`/`is_review_stale` read — pure, no DB of its own.
--- @param rows {read.StaleRow} A `_work.read.stale` call's result
--- @return StaleAges
local function from_rows(rows: {read.StaleRow}): StaleAges
  local claim: Ages = {}
  local review: Ages = {}
  for _, r in ipairs(rows) do
    if r.kind == "claim" then
      claim[r.id] = r.age_s
    elseif r.kind == "review" then
      review[r.id] = r.age_s
    end
  end
  return {claim = claim, review = review}
end

--- Seconds a claim holds without a board commit before it reads as
--- stale. Every board mutation is a commit, so an item being actively
--- worked is touched at its take and again at its handover; between
--- the two there is nothing to commit, which is why the lease is
--- hours against a build dwell measured in minutes. The sessions that
--- claim work here are ephemeral cloud or scheduled runs that cannot
--- drop an item when they die. Takeover is offered, never automatic:
--- the take that re-claims is still a session's explicit act, on the
--- record.
local LEASE_S < const > = 4 * 60 * 60

--- Whether an item's claim has outlived the lease.
--- @param i Item The item
--- @param ages Ages Seconds since last board commit, by id
--- @return boolean True for a claimed item older than the lease
local function is_stale(i: Item, ages: Ages): boolean
  local age = ages[i.id]
  return (i.claim or "") ~= "" and age ~= nil and age > LEASE_S
end

--- Seconds a review claim holds without a board commit before it
--- reads as stale. Short against the build lease, because the two
--- claims lock different amounts of work: a build is take-to-handover
--- against a dwell measured in tens of minutes, a review is
--- read-verify-verdict against a dwell of minutes — a reviewer that
--- has not moved the board inside an hour is gone, and the diff
--- should be offered again.
local REVIEW_LEASE_S < const > = 60 * 60

--- Whether an item's review claim has outlived its lease.
--- @param i Item The item
--- @param ages Ages Seconds since last board commit, by id
--- @return boolean True for a reviewed item older than the review lease
local function is_review_stale(i: Item, ages: Ages): boolean
  local age = ages[i.id]
  return (i.reviewer or "") ~= "" and age ~= nil and age > REVIEW_LEASE_S
end

--- An item's age in whole hours, for rendering.
--- @param i Item The item
--- @param ages Ages Seconds since last board commit, by id
--- @return integer Hours since its last board commit, 0 when unknown
local function stale_hours(i: Item, ages: Ages): integer
  return math.floor((ages[i.id] or 0) / 3600)
end

local record health
  type Ages = Ages
  type StaleAges = StaleAges
  LEASE_S: integer
  is_stale: function(i: Item, ages: Ages): boolean
  REVIEW_LEASE_S: integer
  is_review_stale: function(i: Item, ages: Ages): boolean
  stale_hours: function(i: Item, ages: Ages): integer
  from_rows: function(rows: {read.StaleRow}): StaleAges
end

local M: health = {
  LEASE_S = LEASE_S,
  is_stale = is_stale,
  REVIEW_LEASE_S = REVIEW_LEASE_S,
  is_review_stale = is_review_stale,
  stale_hours = stale_hours,
  from_rows = from_rows,
}

return M
