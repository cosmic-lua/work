#!/usr/bin/env cosmic
-- v3 retains the old CI table only as disposable cache compatibility. No
-- gitboard path observes a provider or treats a check result as board evidence.
local cache = require("_work.cache")
local check = require("cosmic.check")
local ciobs = require("_work.ciobs")
local fixture = require("_work.fixture")
local store = require("_work.store")

local function test_provider_observation_is_an_explicit_refusal()
  local s = fixture.init_state_repo("ciobs-disabled")
  local c = check.must(cache.open(s.root))
  local state, err = ciobs.observe(s, c, "acme/widgets", 7)
  assert(state == nil and err == ciobs.DISABLED, err)
  local live, lerr = ciobs.live(s, "acme/widgets", 7)
  assert(live == nil and lerr == ciobs.DISABLED, lerr)
  assert(cache.close(c))
end

local function test_sync_never_refreshes_provider_state()
  local s = fixture.init_state_repo("ciobs-sync-disabled")
  local _, leaf = fixture.root_with_leaf(s)
  local it = check.must(store.load(s, leaf))
  it.pr = 19 -- a legacy item remains readable, never observable
  assert(not ciobs.is_candidate(it, {[leaf] = 3}))
  assert(#ciobs.at_sync(s) == 0)
end

local function test_legacy_cache_rows_are_readable_but_not_trusted()
  local s = fixture.init_state_repo("ciobs-legacy-row")
  local c = check.must(cache.open(s.root))
  assert(ciobs.record(c, "acme/widgets", 11,
      {state = "green", head_sha = ("a"):rep(40), runs = {}}))
  local state, age = ciobs.read(c, "acme/widgets", 11)
  assert(state == "green" and ciobs.fresh(age), "legacy row remains inspectable")
  assert(ciobs.current_state(c, "acme/widgets", 11, "item") == nil,
    "v3 never treats cached provider state as a workflow fact")
  assert(cache.close(c))
end
