#!/usr/bin/env cosmic
-- `_work.events`: `parse_subject` over every distinct subject shape
-- the log carries today (`_work.gitverbs.tl:239,307,330,430`,
-- `_work.gitgraph.tl:116,176,397`, `_work.gitverdict.tl:292`,
-- `_work.gitcompare.tl:93,147`) plus the legacy ones a real board
-- still holds; `walk` (via a forced `_work.cache.rebuild`) against an
-- independent per-item `git log` for a fixture with three items and a
-- rework round; the save patch keeping `seq` contiguous with no
-- rebuild in between; the fetch patch landing an external commit; and
-- the three `pr_rounds` SELECTs the Evidence section poses.

local cache = require("_work.cache")
local cachedb = require("_work.cachedb")
local check = require("cosmic.check")
local child = require("cosmic.child")
local events = require("_work.events")
local fixture = require("_work.fixture")
local graph = require("_work.gitgraph")
local publish = require("_work.publish")
local refs = require("_work.refs")
local store = require("_work.store")
local vrd = require("_work.gitverdict")
local verbs = require("_work.gitverbs")

local init_state_repo = fixture.init_state_repo
local init_shared = fixture.init_shared
local give_spec = fixture.give_spec

--- `verb`/`session`/`pr` for one subject, asserted in one call.
local function assert_parsed(subject: string, verb: string, session: string, pr: integer)
  local got = events.parse_subject(subject)
  assert(got.verb == verb, ("%q: verb got %q want %q"):format(subject, got.verb, verb))
  assert(got.session == session,
    ("%q: session got %q want %q"):format(subject, got.session, session))
  assert(got.pr == pr, ("%q: pr got %d want %d"):format(subject, got.pr, pr))
end

-- Today's fixed grammar: `take`/`verdict` carry a session and,
-- sometimes, a `pr:N`; the rest carry neither.
local function test_parse_subject_current_verbs()
  assert_parsed("take a1b2c3d4 by session-a pr:7 — awaiting review",
    "take", "session-a", 7)
  assert_parsed("take a1b2c3d4 by session-a", "take", "session-a", 0)
  assert_parsed("verdict a1b2c3d4 accept by session-b — merged abc1234",
    "verdict", "session-b", 0)
  assert_parsed("verdict a1b2c3d4 request changes by session-b",
    "verdict", "session-b", 0)
  assert_parsed("done a1b2c3d4 completed (from doing)", "done", "", 0)
  assert_parsed("new a1b2c3d4 a title here", "new", "", 0)
  assert_parsed("attach a1b2c3d4 under b2c3d4e5", "attach", "", 0)
  assert_parsed("spec a1b2c3d4", "spec", "", 0)
  assert_parsed("block a1b2c3d4 on b2c3d4e5: reason text", "block", "", 0)
  assert_parsed("compare a1b2c3d4 over b2c3d4e5", "compare", "", 0)
  assert_parsed("set a1b2c3d4 title base", "set", "", 0)
  assert_parsed("drop a1b2c3d4: went stale", "drop", "", 0)
  assert_parsed("drop a1b2c3d4 review: handing back", "drop", "", 0)
  assert_parsed("hold a1b2c3d4 verified manually against staging", "hold", "", 0)
end

-- Legacy leading tokens (`_work.flowstats`'s own header names the same
-- set) never refuse — every field just stays at its default, and the
-- subject itself is still there for a reader that cares.
local function test_parse_subject_legacy_shapes()
  assert_parsed("move a1b2c3d4 to a new parent", "move", "", 0)
  assert_parsed("gitboard: legacy migration line", "gitboard:", "", 0)
  assert_parsed("board: legacy line", "board:", "", 0)
  assert_parsed("migrate: legacy line", "migrate:", "", 0)
  assert_parsed("work: legacy line", "work:", "", 0)
  assert_parsed("retitle a1b2c3d4 a new title", "retitle", "", 0)
  assert_parsed("uncompare a1b2c3d4 b2c3d4e5", "uncompare", "", 0)
  assert_parsed("repo a1b2c3d4 owner/name", "repo", "", 0)
end

--- One item's ref, resolved the same way `_work.publish.history` does.
local function item_ref(s: store.Store, id: string): string
  local found = check.must(refs.for_each_ref(s.root,
      {"refs/heads/items/" .. id, "refs/heads/ended/" .. id}))
  assert(#found == 1, "exactly one ref for " .. id)
  return found[1].refname
end

--- Every row a plain `git log` on one ref would give, oldest first,
--- parsed the same way `events.walk` parses its own log line — the
--- independent value `test_rebuild_equals_the_per_item_log` holds
--- `_work.cache.rebuild`'s own `events` rows against.
local function expected_rows(id: string, refname: string, root: string): {events.Row}
  local r = check.must(child.run({"git", "log", "--format=%H\t%ct\t%s", refname},
      {cwd = root}))
  assert(r.ok, "git log failed: " .. r.stderr)
  local lines: {string} = {}
  for line in r.stdout:gmatch("([^\n]+)") do
    lines[#lines + 1] = line
  end
  local out: {events.Row} = {}
  for i = #lines, 1, -1 do
    local sha, at_str, subject = lines[i]:match("^(%S+)\t(%S+)\t(.*)$")
    local parsed = events.parse_subject(subject)
    out[#out + 1] = {
      item = id, seq = #lines - i + 1, sha = sha,
      at = math.tointeger(tonumber(at_str)) or 0,
      verb = parsed.verb, session = parsed.session, pr = parsed.pr, subject = subject,
    }
  end
  return out
end

--- Every `events` row the cache holds for one item, oldest first.
local function cache_rows(c: cache.Cache, id: string): {events.Row}
  local rows = check.must(c.db:query(
      "SELECT seq, sha, at, verb, session, pr, subject FROM events "
      .. "WHERE item = ? ORDER BY seq", {id}))
  local out: {events.Row} = {}
  for row in rows do
    out[#out + 1] = {
      item = id, seq = math.tointeger(row.seq as number) or 0, -- cast: from any (sqlite row)
      sha = row.sha as string, -- cast: from any (sqlite row)
      at = math.tointeger(row.at as number) or 0, -- cast: from any (sqlite row)
      verb = row.verb as string, -- cast: from any (sqlite row)
      session = row.session as string, -- cast: from any (sqlite row)
      pr = math.tointeger(row.pr as number) or 0, -- cast: from any (sqlite row)
      subject = row.subject as string, -- cast: from any (sqlite row)
    }
  end
  assert(rows:err() == nil, "events query failed")
  return out
end

--- One row's fields, joined for a mismatch message.
local function row_text(r: events.Row): string
  return ("seq=%d sha=%s at=%d verb=%s session=%s pr=%d subject=%q"):format(
    r.seq, r.sha, r.at, r.verb, r.session, r.pr, r.subject)
end

--- Fails loudly on the first row that differs, naming the item and index.
local function assert_rows_equal(id: string, want: {events.Row}, got: {events.Row})
  assert(#want == #got,
    ("%s: %d expected rows, %d in the cache"):format(id, #want, #got))
  for i, w in ipairs(want) do
    local g = got[i]
    assert(g.seq == w.seq and g.sha == w.sha and g.at == w.at and g.verb == w.verb
      and g.session == w.session and g.pr == w.pr and g.subject == w.subject,
      ("%s row %d: got %s want %s"):format(id, i, row_text(g), row_text(w)))
  end
end

-- Three items (`fixture.root_with_leaf` files a root, an unreturned
-- peer compared against it, and a leaf under the root) and a rework
-- round on the leaf: taken under one PR, sent back, handed back under
-- a second — `_work.cache.rebuild` (which is what forces the ONE-log
-- `walk`, never the naive per-ref alternative) must equal a plain
-- `git log` on each item's own ref exactly, in order.
local function test_rebuild_equals_the_per_item_log()
  local s = init_state_repo("events-rebuild")
  local root_id, leaf_id = fixture.root_with_leaf(s)
  give_spec(s, leaf_id)
  assert(verbs.cmd_take(s, leaf_id, "session-a", 0, false, "") == 0)
  assert(verbs.cmd_take(s, leaf_id, "session-a", 5, false, "") == 0)
  assert(vrd.cmd_verdict(s, leaf_id, "request changes", 0, "abc1234") == 0,
    "the send-back should be accepted")
  assert(verbs.cmd_take(s, leaf_id, "session-a", 9, false, "") == 0)
  assert(vrd.cmd_verdict(s, leaf_id, "accept", 9, "def5678") == 0,
    "the rework round's accept should be accepted")

  local c = check.must(cache.rebuild(s.root))
  for _, id in ipairs({root_id, leaf_id}) do
    local refname = item_ref(s, id)
    assert_rows_equal(id, expected_rows(id, refname, s.root), cache_rows(c, id))
  end
  check.must(cache.close(c))
end

-- A whole mutation sequence on ONE item, `cachedb.wipe` stubbed to
-- error if called: `_work.cache.heal` is the ONLY thing that calls it
-- (on a genuine patch failure, ahead of a rebuild), so an error here
-- proves the whole sequence stayed on `_work.cache.after_save`'s
-- incremental patch, `seq` picking up exactly where the last write
-- left it, rather than quietly self-healing through a full rebuild.
local function test_save_patch_keeps_seq_contiguous()
  local s = init_state_repo("events-save-seq")
  local _root_id, id = fixture.root_with_leaf(s)
  check.must(cache.close(check.must(cache.open(s.root))))

  local real_wipe = cachedb.wipe
  cachedb.wipe = function(_root: string)
    error("cachedb.wipe must not run: the whole sequence below should "
      .. "stay on the incremental save patch, never a heal", 0)
  end
  local ok, err = pcall(function(): boolean
      give_spec(s, id)
      assert(verbs.cmd_take(s, id, "session-a", 0, false, "") == 0)
      assert(verbs.cmd_take(s, id, "session-a", 3, false, "") == 0)
      assert(vrd.cmd_verdict(s, id, "accept", 3, "cafefeed") == 0)
      return true
    end)
  cachedb.wipe = real_wipe
  if not ok then
    error(err, 0)
  end

  local refname = item_ref(s, id)
  local count_r = check.must(child.run(
      {"git", "rev-list", "--count", refname}, {cwd = s.root}))
  local want_n = math.tointeger(tonumber((count_r.stdout:gsub("%s+$", ""))))

  local c = check.must(cache.open(s.root))
  local rows = cache_rows(c, id)
  check.must(cache.close(c))
  assert(#rows == want_n, ("%d events rows, %d real commits"):format(#rows, want_n))
  for i, row in ipairs(rows) do
    assert(row.seq == i, ("row %d carries seq %d"):format(i, row.seq))
  end
  assert(rows[#rows].verb == "verdict", "the last row is the accept")
end

-- Two clones: `a` writes several commits on one ref before `b` ever
-- syncs (so the first landing is a brand-new ref, `since`'s
-- no-prior-tip branch), then `a` writes one more after `b`'s cache
-- already has a baseline (a true `old..new` range). Either way `b`'s
-- `events` rows for the item must equal `a`'s.
local function test_fetch_patch_lands_new_rows()
  local a, b = init_shared("events-fetch")
  check.must(cache.close(check.must(cache.open(b.root))))
  local _root_id, id = fixture.root_with_leaf(a)
  give_spec(a, id)
  assert(verbs.cmd_take(a, id, "session-a", 0, false, "") == 0)
  assert(publish.sync(b))

  local refname_a = item_ref(a, id)
  local c1 = check.must(cache.open(b.root))
  assert_rows_equal(id, expected_rows(id, refname_a, a.root), cache_rows(c1, id))
  check.must(cache.close(c1))

  assert(graph.cmd_set(a, id, "an item b will fetch, renamed", nil, nil) == 0,
    "the second field write should land")
  assert(publish.sync(b))
  local c2 = check.must(cache.open(b.root))
  assert_rows_equal(id, expected_rows(id, refname_a, a.root), cache_rows(c2, id))
  check.must(cache.close(c2))
end

-- The three questions the Evidence section poses, each one SELECT
-- against `pr_rounds` — the fixture is `leaf_id`'s rework round from
-- `test_rebuild_equals_the_per_item_log`, rebuilt fresh here so this
-- test does not depend on that one's ordering.
local function test_pr_rounds_answers_the_three_questions()
  local s = init_state_repo("events-pr-rounds")
  local _root_id, leaf_id = fixture.root_with_leaf(s)
  give_spec(s, leaf_id)
  assert(verbs.cmd_take(s, leaf_id, "session-a", 0, false, "") == 0)
  assert(verbs.cmd_take(s, leaf_id, "session-a", 5, false, "") == 0)
  assert(vrd.cmd_verdict(s, leaf_id, "request changes", 0, "abc1234") == 0)
  assert(verbs.cmd_take(s, leaf_id, "session-a", 9, false, "") == 0)
  assert(vrd.cmd_verdict(s, leaf_id, "accept", 9, "def5678") == 0)

  local c = check.must(cache.open(s.root))

  -- 1) Which PR heads did this item see, and when.
  local heads = check.must(c.db:query(
      "SELECT pr, taken_at FROM pr_rounds WHERE item = ? ORDER BY pr", {leaf_id}))
  local prs: {integer} = {}
  for row in heads do
    prs[#prs + 1] = math.tointeger(row.pr as number) -- cast: from any (sqlite row)
    assert((row.taken_at as integer) > 0, "every round has a taken_at") -- cast: from any (sqlite row)
  end
  assert(#prs == 2 and prs[1] == 5 and prs[2] == 9,
    "pr 5 then pr 9: " .. table.concat(prs, ","))

  -- 2) How long from take to accept — only pr 9's round landed one.
  local accepted = check.must(c.db:query_one(
      "SELECT accepted_at - taken_at AS lead FROM pr_rounds WHERE item = ? AND pr = 9",
      {leaf_id}))
  assert((accepted.lead as integer) >= 0, "a non-negative lead time") -- cast: from any (sqlite row)
  local still_open = check.must(c.db:query_one(
      "SELECT accepted_at FROM pr_rounds WHERE item = ? AND pr = 5", {leaf_id}))
  assert(still_open.accepted_at == nil, "pr 5 was never accepted")

  -- 3) Every item whose PR was reworked before acceptance: more than
  -- one pr_rounds row.
  local reworked = check.must(c.db:query(
      "SELECT item FROM pr_rounds GROUP BY item HAVING COUNT(*) > 1"))
  local found = false
  for row in reworked do
    if row.item == leaf_id then
      found = true
    end
  end
  assert(found, "the reworked leaf should be named")

  check.must(cache.close(c))
end
