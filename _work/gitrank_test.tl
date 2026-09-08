#!/usr/bin/env cosmic
-- `rank`: an item's position among its siblings — same-parent items
-- against each other, outcomes against outcomes (the board is simply
-- their shared parent) — and the refusals that keep it from doing
-- anything else: a non-sibling X, an unknown id, a self-reference, an
-- unpositioned X, and a done ID.

local check = require("cosmic.check")
local read = require("_work.read")
local graph = require("_work.gitgraph")
local rank = require("_work.gitrank")
local store = require("_work.store")
local storewrite = require("_work.storewrite")
local fixture = require("_work.fixture")
local prepared = require("_work.prepared")
local refs = require("_work.refs")

local init_state_repo = fixture.init_state_repo
local init_shared = fixture.init_shared
local root_with_leaf = fixture.root_with_leaf
local file_item = fixture.file_item
local commits = fixture.commits

-- before/after/last, among parented siblings: each edits the SAME
-- parent's `order`, leaving every other entry where the previous
-- write put it.
local function test_rank_before_after_last_among_parented_siblings()
  local s = init_state_repo("rank-siblings")
  local goal, a = root_with_leaf(s)
  local b = file_item(s, "b", goal)
  local c = file_item(s, "c", goal)
  assert(rank.cmd_rank(s, a, "", "", true) == 0, "a ranks last")
  assert(rank.cmd_rank(s, b, "", "", true) == 0, "b ranks last: a, b")
  assert(rank.cmd_rank(s, c, a, "", false) == 0, "c before a: c, a, b")
  local got = check.must(store.load(s, goal))
  assert(table.concat(got.order, ",") == table.concat({c, a, b}, ","),
    table.concat(got.order, ","))
  assert(rank.cmd_rank(s, c, "", b, false) == 0, "c after b: a, b, c")
  got = check.must(store.load(s, goal))
  assert(table.concat(got.order, ",") == table.concat({a, b, c}, ","),
    table.concat(got.order, ","))
end

-- Two outcomes rank against each other in the BOARD's own `order`,
-- read back on a fresh open of the same repo — never through a
-- separate ref, since the board holds its outcomes' list exactly as
-- any other parent holds its children's.
local function test_rank_among_outcomes_writes_and_reads_back()
  local s = init_state_repo("rank-outcomes")
  local r1 = file_item(s, "outcome one", "")
  local r2 = file_item(s, "outcome two", "")
  check.must(store.list(s))
  local c = check.must(store.read(s))
  local board_id = check.must(read.board(c))
  assert(#(check.must(store.load(s, board_id)).order) == 0,
    "no outcome ranking has been written yet")
  assert(rank.cmd_rank(s, r1, "", "", true) == 0, "r1 ranks last")
  assert(rank.cmd_rank(s, r2, r1, "", false) == 0, "r2 before r1")
  local reopened = check.must(store.open(s.root))
  check.must(store.list(reopened))
  local got = check.must(store.load(reopened, board_id)).order
  assert(#got == 2 and got[1] == r2 and got[2] == r1, table.concat(got, ","))
end

-- ID under a parent and X directly under the board (or under a
-- different parent) are not siblings — refused naming both parents.
local function test_rank_refuses_non_siblings()
  local s = init_state_repo("rank-nonsiblings")
  local _goal, leaf = root_with_leaf(s)
  local other_outcome = file_item(s, "another outcome", "")
  assert(rank.cmd_rank(s, leaf, other_outcome, "", false) ~= 0,
    "leaf is parented under goal, other_outcome under the board: not siblings")
end

local function test_rank_refuses_an_unknown_id()
  local s = init_state_repo("rank-unknown")
  local _goal, leaf = root_with_leaf(s)
  assert(rank.cmd_rank(s, "not-an-item-id", "", "", true) ~= 0)
  assert(rank.cmd_rank(s, leaf, "not-an-item-id", "", false) ~= 0)
end

local function test_rank_refuses_id_equal_to_x()
  local s = init_state_repo("rank-self")
  local _goal, leaf = root_with_leaf(s)
  assert(rank.cmd_rank(s, leaf, leaf, "", false) ~= 0)
end

-- X has to already have a position among ID's siblings — an X that
-- has never been ranked is refused rather than silently placed at the
-- front, with a message pointing at `rank X --last` (or an explicit
-- before/after of X's own).
-- `new` can no longer produce an unranked child under an ordinary
-- parent, so the unpositioned X here is built through a bare
-- `attach`, which still leaves an item unranked when no --before/
-- --after names it.
local function test_rank_refuses_an_unpositioned_x()
  local s = init_state_repo("rank-unpositioned")
  local goal, _leaf = root_with_leaf(s)
  local stray = file_item(s, "a stray outcome", "")
  assert(graph.cmd_attach(s, stray, goal) == 0,
    "attach with no position should be accepted")
  local other = file_item(s, "other", goal)
  assert(rank.cmd_rank(s, other, stray, "", false) ~= 0,
    "stray carries no position among goal's children yet")
end

local function test_rank_refuses_a_done_item()
  local s = init_state_repo("rank-done")
  local goal, leaf = root_with_leaf(s)
  local other = file_item(s, "other", goal)
  assert(rank.cmd_rank(s, other, "", "", true) == 0)
  local it = check.must(store.load(s, leaf))
  it.resolution = "not-planned"
  assert(storewrite.save(s, it, "finish leaf for the test"))
  -- The raw save above bypasses `gitgate.commit_and_publish`'s own
  -- cache patch, so `store.close(s)` is this test's stand-in for
  -- it — leaving the next `store.list` below to reopen fresh instead
  -- of missing the resolution this write just made.
  local _cok, _cerr = store.close(s)
  assert(rank.cmd_rank(s, leaf, other, "", false) ~= 0,
    "a done item's position is not a repair target")
end

-- The board itself has no siblings to rank among.
local function test_rank_refuses_the_board()
  local s = init_state_repo("rank-board")
  check.must(store.list(s))
  local c = check.must(store.read(s))
  local board_id = check.must(read.board(c))
  assert(rank.cmd_rank(s, board_id, "", "", true) ~= 0,
    "the board has no siblings to rank among")
end

-- `rank` leaves any OTHER stray `order` entry untouched — moving
-- everyone else around it rather than pruning it. `attach` prunes ITS
-- OWN stale entry in the same publish now (`_work/gitattach_test.tl`),
-- so this hand-writes a stray entry attach never had a hand in, to
-- isolate `rank`'s own behavior from it.
local function test_rank_leaves_a_stray_entry_untouched()
  local s = init_state_repo("rank-stray")
  local goal, a = root_with_leaf(s)
  local c = file_item(s, "c", goal)
  assert(rank.cmd_rank(s, a, "", "", true) == 0)
  assert(rank.cmd_rank(s, c, "", "", true) == 0) -- a, c
  local elsewhere = file_item(s, "elsewhere", "")
  local stray = check.must(store.load(s, goal))
  stray.order = {stray.order[1], elsewhere, stray.order[2]} -- a, elsewhere, c
  assert(storewrite.save(s, stray, "hand-write a stray order entry"))
  -- The raw save above bypasses `gitgate.commit_and_publish`'s own
  -- cache patch, so `store.close(s)` is this test's stand-in for it.
  local _cok, _cerr = store.close(s)
  assert(rank.cmd_rank(s, a, "", c, false) == 0, "a after c")
  local got = check.must(store.load(s, goal))
  assert(table.concat(got.order, ",") == table.concat({elsewhere, c, a}, ","),
    "the stray entry stays exactly where it was: " .. table.concat(got.order, ","))
end

-- Asking for a position the board already holds is the store's own
-- no-op success, not a fresh commit.
local function test_rank_the_same_position_is_a_noop_success()
  local s = init_state_repo("rank-noop")
  local goal, a = root_with_leaf(s)
  local b = file_item(s, "b", goal)
  assert(rank.cmd_rank(s, a, "", "", true) == 0)
  assert(rank.cmd_rank(s, b, "", "", true) == 0) -- a, b
  local before, seen, old_print = commits(s), "", _G.print
  _G.print = function(msg: any) seen = tostring(msg) end
  local code = rank.cmd_rank(s, b, "", "", true) -- already last
  _G.print = old_print
  assert(code == 0 and commits(s) == before
    and seen:find("nothing to record", 1, true) ~= nil, seen)
end

-- The lost-race re-run pattern (`_work/gitattach_test.tl`'s
-- `test_a_reparent_survives_a_rebase`), against the board's own
-- `order`: the board's own ref tip is the lease, no `seq` involved.
local function test_an_outcome_rank_survives_a_rebase()
  local a, b = init_shared("rank-outcome-race")
  local r1 = file_item(a, "outcome one", "")
  local r2 = file_item(a, "outcome two", "")
  assert(rank.cmd_rank(a, r1, "", "", true) == 0)
  fixture.caller_publish(a)
  fixture.caller_fetch(b)
  assert(rank.cmd_rank(b, r2, "", "", true) == 0,
    "b ranks r2 last first, moving the board's own ref out from under a")
  fixture.caller_publish(b)

  assert(rank.cmd_rank(a, r2, r1, "", false) == 0,
    "the stale caller may prepare against its fetched snapshot")
  local pending = check.must(prepared.list(a.root))
  assert(#pending == 1, "the stale rank has one durable transaction")
  local pushed = prepared.execute(a.root, prepared.push_argv(pending[1]))
  assert(not pushed, "the remote lease, not local preparation, rejects the race")
  assert(prepared.execute(a.root, prepared.fetch_argv()),
    "the caller refreshes its tracking refs after the rejected push")
  check.must(store.close(a))
  local outcomes = check.must(prepared.refresh(a.root))
  assert(#outcomes == 1 and outcomes[1].state == "lost-race",
    "refresh classifies the rejected lease")
  assert(refs.update_ref(a.root, pending[1].staging_ref, refs.ZERO_SHA,
      pending[1].manifest), "the caller discards the diagnosed transaction")

  assert(rank.cmd_rank(a, r2, r1, "", false) == 0,
    "the re-run lands against the merged board")
  fixture.caller_publish(a)
  check.must(store.list(a))
  local c = check.must(store.read(a))
  local board_id = check.must(read.board(c))
  local got = check.must(store.load(a, board_id)).order
  assert(#got == 2 and got[1] == r2 and got[2] == r1, table.concat(got, ","))
end
