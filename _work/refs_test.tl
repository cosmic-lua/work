#!/usr/bin/env cosmic
-- `_work.refs.for_each_ref`'s own parsing: the committer date rides
-- along in the same `for-each-ref` process that already reports each
-- ref's name and object, so `_work.cache`'s digest snapshot and
-- `_work.gitview.list_via_cache` can read a ref's touch time straight
-- off it, with no second per-ref process
-- (`_work.refs.committer_date_unix`) needed for one already named by
-- a snapshot.

local check = require("cosmic.check")
local fixture = require("_work.fixture")
local refs = require("_work.refs")

local function test_for_each_ref_parses_the_committer_date()
  local s = fixture.init_state_repo("refs-committer-date")
  -- The window must bracket the WRITE, not start after it: sampling
  -- `before` once the commit already exists lets a second boundary
  -- land between the two and read `touched` as earlier than `before`.
  local before = os.time()
  local id = fixture.file_item(s, "an outcome", "")
  local found = check.must(refs.for_each_ref(s.root, {"refs/heads/items/" .. id}))
  local after = os.time()
  assert(#found == 1, "the fixture item's own ref, and only it: " .. #found)
  local entry = found[1]
  assert(entry.refname == "refs/heads/items/" .. id, entry.refname)
  assert(entry.sha ~= "", "the object still parses alongside it")
  assert(entry.touched >= before and entry.touched <= after,
    ("the third field should parse as the write's own committer date: "
      .. "got %d, wanted [%d, %d]"):format(entry.touched, before, after))
end
