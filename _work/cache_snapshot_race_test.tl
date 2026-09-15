#!/usr/bin/env cosmic
-- Deterministic stale-composer coverage beside cache_test's real process race.
local check = require("cosmic.check")
local fixture = require("_work.fixture")
local graph = require("_work.gitgraph")
local store = require("_work.store")

-- Two stores capture one canonical head before either writes. The first
-- composition moves the sole snapshot ref; the stale store cannot extend it.
-- After confirmation, the same edit retries and the cache remains readable.
local function test_a_stale_snapshot_writer_retries_without_cache_corruption()
  local seed = fixture.init_state_repo("stale-snapshot")
  local id_x = fixture.file_item(seed, "x before stale composition", "")
  local id_y = fixture.file_item(seed, "y before stale composition", "")
  assert(store.close(seed))
  local first = check.must(store.open(seed.root))
  local stale = check.must(store.open(seed.root))
  assert(graph.cmd_set(first, id_x, "x after first composition", nil, nil) == 0)
  assert(graph.cmd_set(stale, id_y, "y from stale composition", nil, nil) ~= 0,
    "a store captured before the snapshot ref moved is refused")
  fixture.caller_publish(first)
  assert(store.list(first), "the cache remains readable after confirmation")

  local retry = check.must(store.open(seed.root))
  assert(graph.cmd_set(retry, id_y, "y after retry", nil, nil) == 0)
  fixture.caller_publish(retry)
  assert(check.must(store.load(retry, id_x)).title == "x after first composition")
  assert(check.must(store.load(retry, id_y)).title == "y after retry")
end
