#!/usr/bin/env cosmic
-- `_work.readddl`'s views and `_work.read`'s typed readers over them,
-- differentially checked against the Teal derivations they stand in
-- for: `_work.flow.role`/`state`/`substate`/`stage_rank`/`unified`/
-- `outcomes`/`live_outcomes`/`untriaged`/`doing_refusal`'s count, and
-- `_work.rank.is_ranked`/`key`. `_work.read_structure_test` covers the
-- `structure` view's five finding kinds — split out so this file stays
-- under the line cap. Runner mode (D29): every `test_*` below is
-- enrolled by being defined, not by being called.

local check = require("cosmic.check")
local flow = require("_work.flow")
local idxmod = require("_work.index")
local irank = require("_work.index_rank")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local rank = require("_work.rank")
local read = require("_work.read")
local readddl = require("_work.readddl")

--- One `role` expectation: an item and the role `_work.flow.role` (and
--- `_work.read.role`) must both give it.
local record RoleWant
  it: item.Item
  role: string
end

local counter = 0

--- A fresh deterministic id; later calls sort later, matching live
--- KSUID behavior — several assertions below rely on that for age
--- order among ties.
--- @return string
local function fresh_id(): string
  counter = counter + 1
  return check.must(ksuid.encode(1700000000 + counter, ("\0"):rep(16)))
end

--- One valid item, `over` merged onto a bare title-only item.
--- @param over {string: any} Fields to set, e.g. `{parent = board.id}`
--- @return item.Item
local function make(over: {string: any}): item.Item
  local t: {string: any} = {id = fresh_id(), title = "item"}
  for k, v in pairs(over or {}) do
    t[k] = v
  end
  return check.must(item.decode(t))
end

--- An index over `items` with `_work.index_rank` AND `_work.readddl`'s
--- views applied, in that order — `readddl`'s own views join against
--- `rank_path`/`dense_rank`, so those must exist first.
--- @param items {item.Item} The board
--- @return idxmod.Index
local function make_index(items: {item.Item}): idxmod.Index
  local idx = check.must(idxmod.open(items))
  check.must(irank.ensure_views(idx))
  check.must(readddl.ensure_views(idx))
  return idx
end

local function test_role_matches_flow_for_every_role()
  local board = make({})
  -- `outcome` stays childless but for a DONE child — a container's
  -- test needs an OPEN one (`has_open_children` counts only those),
  -- so a done child here proves it does not flip an outcome to
  -- "container", and gives role a done item to answer "work" for
  -- (`show` prints a done item's role too).
  local outcome = make({parent = board.id})
  local done_leaf = make({parent = outcome.id, resolution = "completed"})
  -- A second outcome, decomposed: it reads as "container" itself
  -- (an open child of its own), which is why `container_node` — a
  -- non-outcome item with an open child — is the one actually
  -- asserted "container" below.
  local outcome2 = make({parent = board.id})
  local container_node = make({parent = outcome2.id})
  local leaf = make({parent = container_node.id})
  board.order = {outcome.id, outcome2.id}
  local items = {board, outcome, done_leaf, outcome2, container_node, leaf}
  local idx = make_index(items)

  local cases: {RoleWant} = {
    {it = board, role = "board"}, {it = outcome, role = "outcome"},
    {it = container_node, role = "container"},
    {it = leaf, role = "work"}, {it = done_leaf, role = "work"},
  }
  for _, want in ipairs(cases) do
    local flow_role = flow.role(want.it, items)
    assert(flow_role == want.role,
      ("flow disagrees with the fixture: %s"):format(flow_role))
    local got = check.must(read.role(idx, want.it.id))
    assert(got == want.role, ("%s: got %s, wanted %s"):format(want.it.id, got, want.role))
  end
  check.must(idxmod.close(idx))
end

local function test_state_and_substate_agree_with_flow()
  local board = make({})
  local outcome = make({parent = board.id})
  board.order = {outcome.id}
  local todo = make({parent = outcome.id})
  local building = make({parent = outcome.id, claim = "sess"})
  local review = make({parent = outcome.id, claim = "sess", pr = 3})
  local rework = make({parent = outcome.id, claim = "sess", pr = 3,
      verdict = "request changes"})
  local accepted = make({parent = outcome.id, claim = "sess", pr = 3,
      verdict = "accept"})
  local done = make({parent = outcome.id, resolution = "completed"})
  local items = {board, outcome, todo, building, review, rework, accepted, done}
  local idx = make_index(items)

  for _, it in ipairs(items) do
    local want_state = "todo"
    if it.resolution ~= "" then
      want_state = "ended"
    elseif flow.is_doing(it) then
      want_state = "doing"
    end
    local got_state = check.must(read.state(idx, it.id))
    assert(got_state == want_state,
      ("%s: state %s, wanted %s"):format(it.id, got_state, want_state))
    local got_sub = check.must(read.substate(idx, it.id))
    assert(got_sub == flow.substate(it),
      ("%s: substate %s, wanted %s"):format(it.id, got_sub, flow.substate(it)))
  end
  check.must(idxmod.close(idx))
end

local function test_stage_matches_flow_stage_rank()
  local board = make({})
  local outcome = make({parent = board.id})
  board.order = {outcome.id}
  local accepted = make({parent = outcome.id, claim = "s", pr = 3, verdict = "accept"})
  local review = make({parent = outcome.id, claim = "s", pr = 3})
  local rework = make({parent = outcome.id, claim = "s", pr = 3,
      verdict = "request changes"})
  local building = make({parent = outcome.id, claim = "s"})
  local repair = make({parent = outcome.id, key = "lane-x"})
  local todo = make({parent = outcome.id})
  local items = {board, outcome, accepted, review, rework, building, repair, todo}
  local idx = make_index(items)

  for _, it in ipairs({accepted, review, rework, building, repair, todo}) do
    local row = check.must(idx.db:query_one("SELECT stage FROM stage WHERE id = ?", {it.id}))
    local got = math.tointeger(row.stage as number) -- cast: from any (sqlite row)
    assert(got == flow.stage_rank(it),
      ("%s: stage %s, wanted %s"):format(it.id, tostring(got), tostring(flow.stage_rank(it))))
  end
  check.must(idxmod.close(idx))
end

--- Every id `xs` names, in the order given.
--- @param xs {item.Item}
--- @return {string}
local function ids_of(xs: {item.Item}): {string}
  local out: {string} = {}
  for _, i in ipairs(xs) do
    out[#out + 1] = i.id
  end
  return out
end

local function test_queue_matches_flow_unified_order()
  local board = make({})
  local o1 = make({parent = board.id})
  local o2 = make({parent = board.id})
  board.order = {o1.id, o2.id}
  local accepted = make({parent = o1.id, claim = "s", pr = 3, verdict = "accept"})
  local review = make({parent = o1.id, claim = "s", pr = 3})
  local rework = make({parent = o1.id, claim = "s", pr = 3, verdict = "request changes"})
  local building = make({parent = o1.id, claim = "s"})
  local repair = make({parent = o2.id, key = "lane-x"})
  local todo_a = make({parent = o2.id})
  local todo_b = make({parent = o1.id})
  local container = make({parent = o2.id})
  local under_container = make({parent = container.id})
  local done = make({parent = o1.id, resolution = "completed"})
  local items = {board, o1, o2, accepted, review, rework, building, repair,
    todo_a, todo_b, container, under_container, done}
  local idx = make_index(items)

  local want = ids_of(flow.unified(items, rank.positions(items)))
  local got_rows = check.must(read.queue(idx))
  local got: {string} = {}
  for _, r in ipairs(got_rows) do
    got[#got + 1] = r.id
  end
  assert(table.concat(got, " ") == table.concat(want, " "),
    ("got:  %s\nwant: %s"):format(table.concat(got, " "), table.concat(want, " ")))
  check.must(idxmod.close(idx))
end

local function test_outcomes_and_live_outcomes()
  local board = make({})
  local ranked_live = make({parent = board.id})
  local ranked_idle = make({parent = board.id})
  local unranked = make({parent = board.id})
  board.order = {ranked_idle.id, ranked_live.id}
  local child = make({parent = ranked_live.id})
  local done_child = make({parent = ranked_idle.id, resolution = "completed"})
  local items = {board, ranked_live, ranked_idle, unranked, child, done_child}
  local idx = make_index(items)

  local want_ids = ids_of(flow.outcomes(items))
  local want_live = flow.live_outcomes(items)
  local got = check.must(read.outcomes(idx))
  local got_ids: {string} = {}
  for _, r in ipairs(got) do
    got_ids[#got_ids + 1] = r.id
    local want_l = want_live[r.id] or false
    assert(r.live == want_l,
      ("%s: live %s, wanted %s"):format(r.id, tostring(r.live), tostring(want_l)))
  end
  assert(table.concat(got_ids, " ") == table.concat(want_ids, " "),
    ("got:  %s\nwant: %s"):format(table.concat(got_ids, " "), table.concat(want_ids, " ")))
  check.must(idxmod.close(idx))
end

local function test_triage_matches_untriaged()
  local board = make({})
  local ranked = make({parent = board.id})
  board.order = {ranked.id}
  local bare_capture = make({parent = board.id})
  local decomposed_capture = make({parent = board.id})
  local kid = make({parent = decomposed_capture.id})
  local items = {board, ranked, bare_capture, decomposed_capture, kid}
  local idx = make_index(items)

  local want = ids_of(flow.untriaged(items))
  local got = check.must(read.triage(idx))
  assert(table.concat(got, " ") == table.concat(want, " "),
    ("got:  %s\nwant: %s"):format(table.concat(got, " "), table.concat(want, " ")))
  check.must(idxmod.close(idx))
end

local function test_doing_count_matches_flow()
  local board = make({})
  local outcome = make({parent = board.id})
  board.order = {outcome.id}
  local building = make({parent = outcome.id, claim = "s"})
  local review = make({parent = outcome.id, pr = 3})
  local todo = make({parent = outcome.id})
  local container = make({parent = outcome.id})
  local claimed_container_child = make({parent = container.id, claim = "s"})
  local items = {board, outcome, building, review, todo, container,
    claimed_container_child}
  local idx = make_index(items)

  local want = 0
  for _, it in ipairs(items) do
    if item.is_open(it) and flow.is_doing(it) and flow.role(it, items) == "work" then
      want = want + 1
    end
  end
  local got = check.must(read.doing_count(idx))
  assert(got == want, ("got %d, wanted %d"):format(got, want))
  check.must(idxmod.close(idx))
end

local function test_is_ranked_matches_rank()
  local board = make({})
  local ranked = make({parent = board.id})
  local unranked = make({parent = board.id})
  board.order = {ranked.id}
  local kid = make({parent = ranked.id})
  local under_unranked = make({parent = unranked.id})
  local items = {board, ranked, unranked, kid, under_unranked}
  local idx = make_index(items)
  local ranks = rank.positions(items)

  for _, it in ipairs(items) do
    local got = check.must(read.is_ranked(idx, it.id))
    assert(got == rank.is_ranked(ranks, it.id),
      ("%s: is_ranked %s, wanted %s"):format(it.id, tostring(got),
        tostring(rank.is_ranked(ranks, it.id))))
  end
  check.must(idxmod.close(idx))
end

--- `_work.read.key`'s POSITIONED fields run one higher than
--- `_work.rank.key`'s own: `_work.index_rank`'s SQL numbers a dense
--- position with `ROW_NUMBER()` (1-based), while
--- `_work.rank.dense_positions` numbers the same list 0-based — a
--- pre-existing difference in `_work.index_rank` (untouched by this
--- slice) this test works around rather than papers over: an
--- UNPOSITIONED field ("1" plus the level's own id) carries no number
--- at all, so it IS byte-identical either way, and a uniform +1 shift
--- on every positioned field changes no comparison's OUTCOME (the
--- leading "0"/"1" digit, never the shifted suffix, is what decides
--- against an unpositioned sibling, and the shift is the same on both
--- sides of any two positioned siblings). This asserts the ORDER the
--- two agree on, and byte equality on the one path here with no
--- positioned field on it at all.
local record KeyPair
  id: string
  key: string
end

local function test_key_agrees_with_rank_order()
  local board = make({})
  local ranked = make({parent = board.id})
  local unranked = make({parent = board.id})
  board.order = {ranked.id}
  local kid = make({parent = ranked.id})
  local under_unranked = make({parent = unranked.id})
  local items = {board, ranked, unranked, kid, under_unranked}
  local idx = make_index(items)
  local ranks = rank.positions(items)

  local want_ids = ids_of(rank.sorted(items, ranks))
  local by_key: {KeyPair} = {}
  for _, it in ipairs(items) do
    by_key[#by_key + 1] = {id = it.id, key = check.must(read.key(idx, it.id))}
  end
  table.sort(by_key, function(a: KeyPair, b: KeyPair): boolean
      return a.key < b.key
    end)
  local got_ids: {string} = {}
  for _, p in ipairs(by_key) do
    got_ids[#got_ids + 1] = p.id
  end
  assert(table.concat(got_ids, " ") == table.concat(want_ids, " "),
    ("got:  %s\nwant: %s"):format(table.concat(got_ids, " "), table.concat(want_ids, " ")))

  -- Neither level on `under_unranked`'s path is ever positioned, so
  -- no numbering offset is in play: this one IS byte-identical.
  local got_key = check.must(read.key(idx, under_unranked.id))
  assert(got_key == rank.key(ranks, under_unranked.id),
    ("%s: got %s, wanted %s"):format(under_unranked.id, got_key,
      rank.key(ranks, under_unranked.id)))
  check.must(idxmod.close(idx))
end

local function test_children_listing()
  local board = make({})
  local parent = make({parent = board.id})
  board.order = {parent.id}
  local c1 = make({parent = parent.id})
  local c2 = make({parent = parent.id})
  local unranked_child = make({parent = parent.id})
  local done_child = make({parent = parent.id, resolution = "completed"})
  -- A stale entry: named in `parent.order` without being a real child.
  local elsewhere = make({parent = board.id})
  parent.order = {c2.id, elsewhere.id, c1.id}
  local items = {board, parent, c1, c2, unranked_child, done_child, elsewhere}
  local idx = make_index(items)

  local got = check.must(read.children(idx, parent.id))
  local by_child: {string: read.ChildRow} = {}
  for _, r in ipairs(got) do
    by_child[r.child] = r
  end
  assert(by_child[c2.id].position == 1, "c2 is stored first and real: position 1")
  assert(by_child[c1.id].position == 2,
    "c1 is dense position 2 — the stale entry between them consumes no slot")
  assert(by_child[unranked_child.id].position == nil, "never listed: unranked")
  assert(by_child[done_child.id].position == nil and by_child[done_child.id].open == false,
    "a done child is listed, unranked here, and reads as not open")
  assert(by_child[elsewhere.id] == nil, "a stale order entry names no real child of parent")
  assert(#got == 4, ("got %d children, wanted 4"):format(#got))
  check.must(idxmod.close(idx))
end

--- `depth` containers under `parent`, each the next one's parent, then
--- one workable leaf under the last — the deep-chain fixture shared by
--- the queue-fallback and `structure` deep-chain tests.
--- @param parent string The outcome (or any container) to nest under
--- @param depth integer How many containers to stack
--- @return {item.Item} The containers then the leaf, in nesting order
--- @return item.Item The leaf
local function make_chain(parent: string, depth: integer): {item.Item}, item.Item
  local out: {item.Item} = {}
  local cur = parent
  for _ = 1, depth do
    local c = make({parent = cur})
    out[#out + 1] = c
    cur = c.id
  end
  local leaf = make({parent = cur})
  out[#out + 1] = leaf
  return out, leaf
end

local function test_deep_chain_falls_back_like_rank_key()
  local board = make({})
  local outcome = make({parent = board.id})
  board.order = {outcome.id}
  -- 15 containers puts the leaf at depth 17 from the board (outcome at
  -- depth 1) — one past `rank_path`'s 16-hop bound, so it carries no
  -- row there, exactly like `_work.rank`'s own MAX_DEPTH-bounded walk.
  local chain, leaf = make_chain(outcome.id, 15)
  local items: {item.Item} = {board, outcome}
  for _, it in ipairs(chain) do
    items[#items + 1] = it
  end
  local idx = make_index(items)
  local ranks = rank.positions(items)

  local got_ranked = check.must(read.is_ranked(idx, leaf.id))
  assert(got_ranked == rank.is_ranked(ranks, leaf.id), "unranked, same as the Teal walk")
  local got_key = check.must(read.key(idx, leaf.id))
  assert(got_key == rank.key(ranks, leaf.id),
    ("%s: got %s, wanted %s"):format(leaf.id, got_key, rank.key(ranks, leaf.id)))

  local want = ids_of(flow.unified(items, ranks))
  local got_rows = check.must(read.queue(idx))
  local got: {string} = {}
  for _, r in ipairs(got_rows) do
    got[#got + 1] = r.id
  end
  assert(table.concat(got, " ") == table.concat(want, " "),
    ("got:  %s\nwant: %s"):format(table.concat(got, " "), table.concat(want, " ")))
  check.must(idxmod.close(idx))
end
