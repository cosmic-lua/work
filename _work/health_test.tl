#!/usr/bin/env cosmic
-- The stall detectors are pure over the item list plus caller-supplied
-- ages: a claim or review claim never reads stale without evidence,
-- and only past its own lease.

local check = require("cosmic.check")
local health = require("_work.health")
local item = require("_work.item")
local ksuid = require("_work.ksuid")

local counter = 0

--- A fresh deterministic id; later calls sort later.
local function fresh_id(): string
  counter = counter + 1
  return check.must(ksuid.encode(1700000000 + counter, ("\0"):rep(16)))
end

--- One valid item.
local function make(over: {string: any}): item.Item
  local t: {string: any} = {id = fresh_id(), title = "item"}
  for k, v in pairs(over or {}) do
    t[k] = v
  end
  return check.must(item.decode(t))
end

local function test_staleness_needs_a_claim_and_an_age_past_the_lease()
  local root = make({})
  local claimed = make({parent = root.id, claim = "session-B"})
  local unclaimed = make({parent = root.id})
  assert(not health.is_stale(claimed, {}),
    "no age recorded never reads as stale")
  assert(not health.is_stale(claimed, {[claimed.id] = health.LEASE_S}),
    "the lease boundary itself still holds")
  assert(health.is_stale(claimed, {[claimed.id] = health.LEASE_S + 1}),
    "past it the claim is stale")
  assert(not health.is_stale(unclaimed, {[unclaimed.id] = health.LEASE_S * 2}),
    "an unclaimed item has no claim to go stale")
  assert(health.stale_hours(claimed, {[claimed.id] = 5 * 60 * 60}) == 5,
    "hours render whole")
end

local function test_review_staleness_runs_on_its_own_shorter_lease()
  local root = make({})
  local reading = make({parent = root.id, claim = "builder", pr = 7,
      reviewer = "review-1"})
  assert(not health.is_review_stale(reading,
      {[reading.id] = health.REVIEW_LEASE_S}),
    "the review lease boundary holds")
  assert(health.is_review_stale(reading,
      {[reading.id] = health.REVIEW_LEASE_S + 1}),
    "past it the diff is anyone's again")
end
