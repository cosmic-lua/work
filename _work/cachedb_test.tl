#!/usr/bin/env cosmic
-- `_work.cachedb`'s pure helpers: `digest_of`'s order-independence,
-- and `changed_ids`' appear/
-- disappear/move coverage. `ensure_gitignore`, `path_of`, and the
-- meta/user_version primitives are exercised through `_work.cache`'s
-- own tests, which need a real repository to mean anything.

local cachedb = require("_work.cachedb")

local function test_digest_of_is_order_independent()
  local a = cachedb.digest_of({
      {refname = "refs/heads/state", sha = "1"},
      {refname = "refs/heads/board/format", sha = "2"},
    })
  local b = cachedb.digest_of({
      {refname = "refs/heads/board/format", sha = "2"},
      {refname = "refs/heads/state", sha = "1"},
    })
  assert(a == b, "sorted before hashing, so listing order never matters")
  assert(#a == 64, "sha256 hex is 64 characters: " .. tostring(#a))
end

local function test_digest_of_changes_when_a_sha_changes()
  local a = cachedb.digest_of({{refname = "refs/heads/state", sha = "1"}})
  local b = cachedb.digest_of({{refname = "refs/heads/state", sha = "2"}})
  assert(a ~= b, "a moved ref is a different digest")
end

local function test_changed_ids_finds_appeared_disappeared_and_moved()
  local before = {a = "1", b = "2", c = "3"}
  local after = {a = "1", b = "9", d = "4"}
  local changed = cachedb.changed_ids(before, after)
  table.sort(changed)
  assert(#changed == 3, table.concat(changed, ","))
  assert(changed[1] == "b", "moved") -- sha changed
  assert(changed[2] == "c", "disappeared")
  assert(changed[3] == "d", "appeared")
end

local function test_changed_ids_is_empty_when_nothing_moved()
  local same = {a = "1", b = "2"}
  local changed = cachedb.changed_ids(same, {a = "1", b = "2"})
  assert(#changed == 0, table.concat(changed, ","))
end
