#!/usr/bin/env cosmic
-- Remote-mode cache behavior at the caller-owned transport boundary.

local cache = require("_work.cache")
local cachedb = require("_work.cachedb")
local cachequery = require("_work.cachequery")
local check = require("cosmic.check")
local fixture = require("_work.fixture")
local graph = require("_work.gitgraph")
local gitrank = require("_work.gitrank")
local item = require("_work.item")
local read = require("_work.read")
local sqlite = require("cosmic.sqlite")
local store = require("_work.store")

local function test_a_caller_fetch_invalidates_the_cache_until_the_next_open_rebuilds_it()
  local a, b = fixture.init_shared("outcome-rank-fetch")
  local root = fixture.file_item(a, "an outcome", "")
  fixture.caller_fetch(b)
  check.must(cache.close(check.must(cache.open(b.root))))
  local before_raw = check.must(sqlite.open(cache.path_of(b.root)))
  local before_digest = check.must(cachedb.meta_get(before_raw, "refs_digest"))
  check.must(before_raw:close())

  assert(gitrank.cmd_rank(a, root, "", "", true) == 0)
  fixture.caller_publish(a)
  fixture.caller_fetch(b)

  local after_raw = check.must(sqlite.open(cache.path_of(b.root)))
  local after_digest = check.must(cachedb.meta_get(after_raw, "refs_digest"))
  check.must(after_raw:close())
  assert(after_digest == before_digest,
    "caller-owned fetch moves refs only; the disposable cache is still stale")

  local c = check.must(cache.open(b.root))
  local rebuilt_digest = check.must(cachedb.meta_get(c.db, "refs_digest"))
  assert(rebuilt_digest ~= before_digest,
    "the next guarded cache open rebuilds against fetched canonical refs")
  local all = check.must(cachequery.items(c))
  local board_id = check.must(read.board(c))
  check.must(cache.close(c))
  local board = check.must(item.by_id(all)[board_id], "the board is among the items")
  assert(table.concat(board.order, " ") == root,
    "the board order comes from the fetched canonical ref")
end

-- Preparing a remote successor must not patch it under the still-current
-- canonical digest. It becomes readable only after caller transport.
local function test_a_prepared_remote_mutation_stays_out_of_the_read_model_until_confirmed()
  local s, _other = fixture.init_shared("prepared-cache-isolation")
  local id = fixture.file_item(s, "confirmed title", "")
  assert(graph.cmd_set(s, id, "prepared title", nil, nil) == 0)

  local before = check.must(store.list(s))
  local before_item = check.must(item.by_id(before)[id])
  assert(before_item.title == "confirmed title",
    "an unconfirmed prepared mutation is not readable: " .. before_item.title)

  fixture.caller_publish(s)
  local after = check.must(store.list(s))
  local after_item = check.must(item.by_id(after)[id])
  assert(after_item.title == "prepared title",
    "caller push+fetch makes the successor canonical: " .. after_item.title)
end
