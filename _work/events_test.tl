#!/usr/bin/env cosmic
-- Event history remains a Git-derived audit view in v3. Current workflow
-- subjects identify product work by commit id; PR numbers are parsed only so
-- pre-v3 history remains readable during migration.
local cache = require("_work.cache")
local check = require("cosmic.check")
local child = require("cosmic.child")
local events = require("_work.events")
local fixture = require("_work.fixture")
local item = require("_work.item")
local refs = require("_work.refs")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

local BASE < const > = ("a"):rep(40)
local HEAD < const > = ("b"):rep(40)

local function test_parse_subject_commit_lifecycle()
  local take = events.parse_subject(
    "take a1b2c3d4 by session-a head:bBBBBBBBBBBB")
  assert(take.verb == "take" and take.session == "session-a")
  assert(take.head == "bbbbbbbbbbbb" and take.pr == 0)
  local verdict = events.parse_subject(
    "verdict a1b2c3d4 request changes head:cafefeed1234 by reviewer-a")
  assert(verdict.verb == "verdict" and verdict.session == "reviewer-a")
  assert(verdict.head == "cafefeed1234" and verdict.pr == 0)
  local done = events.parse_subject("done a1b2c3d4 completed (from accepted)")
  assert(done.verb == "done" and done.head == "" and done.pr == 0)
end

local function test_parse_subject_keeps_legacy_history_readable()
  local legacy = events.parse_subject("take a1b2c3d4 by old-session pr:17")
  assert(legacy.verb == "take" and legacy.session == "old-session")
  assert(legacy.pr == 17 and legacy.head == "")
  local unknown = events.parse_subject("board: legacy migration line")
  assert(unknown.verb == "board:" and unknown.head == "")
end

local function item_ref(s: store.Store, id: string): string
  local found = check.must(refs.for_each_ref(s.root,
      {"refs/heads/items/" .. id, "refs/heads/ended/" .. id}))
  assert(#found == 1)
  return found[1].refname
end

local function commit_handover(s: store.Store, id: string)
  local it = check.must(store.load(s, id))
  it.repo, it.claim, it.claim_base = "acme/widgets", "session-a", BASE
  it.handover_head = HEAD
  assert(item.record_involvement(it.builders, "session-a"))
  assert(storewrite.save(s, it,
      ("take %s by session-a head:%s"):format(id:sub(1, 8), HEAD:sub(1, 12))))
end

local function test_cache_rebuild_matches_the_git_commit_chain()
  local s = fixture.init_state_repo("events-v3-rebuild")
  local _, leaf = fixture.root_with_leaf(s)
  fixture.give_spec(s, leaf)
  commit_handover(s, leaf)
  local it = check.must(store.load(s, leaf))
  it.verdict, it.verdict_head = "request changes", HEAD
  assert(storewrite.save(s, it,
      ("verdict %s request changes head:%s by reviewer-a")
      :format(leaf:sub(1, 8), HEAD:sub(1, 12))))

  local refname = item_ref(s, leaf)
  local log = check.must(child.run(
      {"git", "log", "--format=%H\t%s", "--reverse", refname}, {cwd = s.root}))
  assert(log.ok, log.stderr)
  local expected: {string} = {}
  for line in log.stdout:gmatch("([^\n]+)") do expected[#expected + 1] = line end

  local c = check.must(cache.rebuild(s.root))
  local rows = check.must(c.db:query(
      "SELECT sha, subject FROM events WHERE item = ? ORDER BY seq", {leaf}))
  local got: {string} = {}
  for row in rows do
    local sha = row.sha as string -- cast: sqlite row
    local subject = row.subject as string -- cast: sqlite row
    got[#got + 1] = sha .. "\t" .. subject
  end
  assert(rows:err() == nil and #got == #expected)
  for n, line in ipairs(expected) do assert(got[n] == line, got[n]) end
  assert(cache.close(c))
end

local function test_incremental_patch_keeps_event_sequence_contiguous()
  local s = fixture.init_state_repo("events-v3-save")
  local _, leaf = fixture.root_with_leaf(s)
  check.must(cache.close(check.must(cache.open(s.root))))
  fixture.give_spec(s, leaf)
  commit_handover(s, leaf)
  local c = check.must(cache.open(s.root))
  local rows = check.must(c.db:query(
      "SELECT seq FROM events WHERE item = ? ORDER BY seq", {leaf}))
  local count = 0
  for row in rows do
    count = count + 1
    local seq = math.tointeger(row.seq as number) -- cast: sqlite row
    assert(seq == count)
  end
  assert(rows:err() == nil and count >= 3)
  assert(cache.close(c))
end
