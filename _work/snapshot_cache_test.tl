#!/usr/bin/env cosmic
--- Every local snapshot publication patches its warm query projection once.
local cache = require("_work.cache")
local cachedb = require("_work.cachedb")
local check = require("cosmic.check")
local fixture = require("_work.fixture")
local publish = require("_work.publish")
local stateclaim = require("_work.stateclaim")
local statewrite = require("_work.statewrite")
local store = require("_work.store")

local function test_direct_log_and_claim_changes_patch_without_rebuilding()
  local s = fixture.init_state_repo("cache-direct-native")
  local id = fixture.file_item(s, "Native cache subject", "")
  assert(cache.close(check.must(cache.open(s.root))))
  local original = cachedb.wipe
  local rebuilt = 0
  cachedb.wipe = function(root: string)
    rebuilt = rebuilt + 1
    original(root)
  end
  local ok, err = pcall(function()
      local it = check.must(store.load(s, id))
      assert(statewrite.log(s, it, "log native cache", "Durable findings"))
      assert(publish.publish(s))
      local c = check.must(cache.open(s.root))
      assert(cachedb.meta_get(c.db, "refs_digest") == s.state_head)
      assert(check.must(c.db:query_one("SELECT subject FROM events WHERE item = ? ORDER BY seq DESC LIMIT 1", {id})).subject == "log native cache")
      assert(cache.close(c))
      local now = os.time()
      for n, action in ipairs({"take", "renew", "drop"} as {stateclaim.Action}) do -- cast: literal action sequence
        local result = stateclaim.prepare(s.root, s.state_head,
          {{id = id, product_base = string.rep("a", 40)}}, action, "cache-holder", now + n, false, "")
        assert(next(result.refused) == nil and #result.changes > 0)
        for _, dependency in ipairs(result.dependencies) do
          s.state_paths[dependency.path], s.state_reads[dependency.path] = dependency.id, dependency.id
        end
        s.op, s.session = action, "cache-holder"
        assert(statewrite.transition(s, result.changes, action .. " native cache", result.publish_by))
        assert(publish.publish(s))
        c = check.must(cache.open(s.root))
        assert(cachedb.meta_get(c.db, "refs_digest") == s.state_head)
        local row = check.must(c.db:query_one("SELECT claim FROM items WHERE id = ?", {id}))
        assert(row.claim == (action == "drop" and "" or "cache-holder"))
        assert(check.must(c.db:query_one("SELECT subject FROM events WHERE item = ? ORDER BY seq DESC LIMIT 1", {id})).subject == action .. " native cache")
        assert(cache.close(c))
      end
      assert(rebuilt == 0, "direct publications keep the warm cache incrementally current")
    end)
  cachedb.wipe = original
  assert(ok, err)
end
