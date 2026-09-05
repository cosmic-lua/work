#!/usr/bin/env cosmic
-- `_work.readddl`'s views and `_work.read`'s typed readers over them,
-- checked as queries over fixture rows loaded into an in-memory
-- database against literal expected rows — the design's own rule
-- (`docs/design/read.md`): a derived fact is tested this way, never
-- through a Teal reimplementation. `_work.read_structure_test` covers
-- the `structure` view's five finding kinds — split out so this file
-- stays under the line cap. Runner mode (D29): every `test_*` below is
-- enrolled by being defined, not by being called.

local check = require("cosmic.check")
local fixture = require("_work.fixture")
local flow = require("_work.flow")
local idxmod = require("_work.index")
local index_rank = require("_work.index_rank")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local read = require("_work.read")
local readddl = require("_work.readddl")

local make_index = fixture.make_index

--- One `role` expectation: an item and the role `_work.read.role`
--- must give it.
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

local function test_role_for_every_role()
  local board = make({})
  -- `outcome` stays childless but for a DONE child — a container's
  -- test needs an OPEN one (only those make a container), so a done
  -- child here proves it does not flip an outcome to "container", and
  -- gives role a done item to answer "work" for (`show` prints a done
  -- item's role too).
  local outcome = make({parent = board.id})
  local done_leaf = make({parent = outcome.id, resolution = "completed"})
  -- A second outcome, decomposed: it reads as "container" itself (an
  -- open child of its own), which is why `container_node` — a
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
    local got = check.must(read.role(idx, want.it.id))
    assert(got == want.role, ("%s: got %s, wanted %s"):format(want.it.id, got, want.role))
  end
  check.must(idxmod.close(idx))
end

local function test_state_and_substate()
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
  local idx = make_index({board, outcome, todo, building, review, rework,
      accepted, done})

  local cases = {
    {it = board, state = "todo", substate = "building"},
    {it = outcome, state = "todo", substate = "building"},
    {it = todo, state = "todo", substate = "building"},
    {it = building, state = "doing", substate = "building"},
    {it = review, state = "doing", substate = "review"},
    {it = rework, state = "doing", substate = "rework"},
    {it = accepted, state = "doing", substate = "accepted"},
    {it = done, state = "ended", substate = "building"},
  }
  for _, c in ipairs(cases) do
    local got_state = check.must(read.state(idx, c.it.id))
    assert(got_state == c.state,
      ("%s: state %s, wanted %s"):format(c.it.id, got_state, c.state))
    local got_sub = check.must(read.substate(idx, c.it.id))
    assert(got_sub == c.substate,
      ("%s: substate %s, wanted %s"):format(c.it.id, got_sub, c.substate))
  end
  check.must(idxmod.close(idx))
end

local function test_stage_runs_accepted_to_todo()
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
  local idx = make_index({board, outcome, accepted, review, rework, building,
      repair, todo})

  local cases = {
    {it = accepted, stage = flow.STAGE_ACCEPTED},
    {it = review, stage = flow.STAGE_REVIEW},
    {it = rework, stage = flow.STAGE_REWORK},
    {it = building, stage = flow.STAGE_BUILDING},
    {it = repair, stage = flow.STAGE_REPAIR},
    {it = todo, stage = flow.STAGE_TODO},
  }
  for _, c in ipairs(cases) do
    local row = check.must(idx.db:query_one("SELECT stage FROM stage WHERE id = ?", {c.it.id}))
    local got = math.tointeger(row.stage as number) -- cast: from any (sqlite row)
    assert(got == c.stage,
      ("%s: stage %s, wanted %s"):format(c.it.id, tostring(got), tostring(c.stage)))
  end
  check.must(idxmod.close(idx))
end

-- The unified queue: stage first — accepted, review, rework, building,
-- lane repair, todo — then rank path within a stage, age last. Two
-- outcomes (o1 before o2 in the board's own order) give the todo
-- bucket a real tie to break: `todo_b` (under o1) outranks both
-- `todo_a` and `under_container` (under o2, at different depths —
-- ranking by outcome first means depth past it never matters), and
-- between those two — tied through o2, both unranked at the next
-- level — age decides: `todo_a` was minted before `container`.
local function test_queue_orders_stage_then_rank_then_age()
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
  local idx = make_index({board, o1, o2, accepted, review, rework, building,
      repair, todo_a, todo_b, container, under_container, done})

  local want = {accepted.id, review.id, rework.id, building.id, repair.id,
    todo_b.id, todo_a.id, under_container.id}
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
  local idx = make_index({board, ranked_live, ranked_idle, unranked, child,
      done_child})

  local want_ids = {ranked_idle.id, ranked_live.id}
  local want_live: {string: boolean} = {[ranked_idle.id] = false, [ranked_live.id] = true}
  local got = check.must(read.outcomes(idx))
  local got_ids: {string} = {}
  for _, r in ipairs(got) do
    got_ids[#got_ids + 1] = r.id
    assert(r.live == want_live[r.id],
      ("%s: live %s, wanted %s"):format(r.id, tostring(r.live), tostring(want_live[r.id])))
  end
  assert(table.concat(got_ids, " ") == table.concat(want_ids, " "),
    ("got:  %s\nwant: %s"):format(table.concat(got_ids, " "), table.concat(want_ids, " ")))
  check.must(idxmod.close(idx))
end

local function test_triage_holds_unranked_childless_outcomes()
  local board = make({})
  local ranked = make({parent = board.id})
  board.order = {ranked.id}
  local bare_capture = make({parent = board.id})
  -- An unranked outcome already being decomposed is not triage either
  -- — only a CHILDLESS, unranked outcome is.
  local decomposed_capture = make({parent = board.id})
  local kid = make({parent = decomposed_capture.id})
  local idx = make_index({board, ranked, bare_capture, decomposed_capture, kid})

  local got = check.must(read.triage(idx))
  assert(#got == 1 and got[1] == bare_capture.id,
    ("got: %s, wanted only %s"):format(table.concat(got, " "), bare_capture.id))
  check.must(idxmod.close(idx))
end

local function test_doing_count_holds_open_workable_leaves_only()
  local board = make({})
  local outcome = make({parent = board.id})
  board.order = {outcome.id}
  local building = make({parent = outcome.id, claim = "s"})
  local review = make({parent = outcome.id, pr = 3})
  local todo = make({parent = outcome.id})
  local container = make({parent = outcome.id})
  local claimed_container_child = make({parent = container.id, claim = "s"})
  local idx = make_index({board, outcome, building, review, todo, container,
      claimed_container_child})

  -- The container itself is never counted, claimed or not — only a
  -- WORK item (a childless leaf) is; `building`, `review` and its own
  -- claimed child are the three.
  local got = check.must(read.doing_count(idx))
  assert(got == 3, ("got %d, wanted 3"):format(got))
  check.must(idxmod.close(idx))
end

local function test_is_ranked_follows_the_outcome_level_alone()
  local board = make({})
  local ranked = make({parent = board.id})
  local unranked = make({parent = board.id})
  board.order = {ranked.id}
  local kid = make({parent = ranked.id})
  local under_unranked = make({parent = unranked.id})
  local idx = make_index({board, ranked, unranked, kid, under_unranked})

  local cases = {
    {it = board, want = true}, {it = ranked, want = true},
    {it = unranked, want = false},
    -- `kid`'s own position among `ranked`'s children is never asked:
    -- its OUTCOME (`ranked` itself) is positioned, which is the whole
    -- of what "not triage" means.
    {it = kid, want = true},
    {it = under_unranked, want = false},
  }
  for _, c in ipairs(cases) do
    local got = check.must(read.is_ranked(idx, c.it.id))
    assert(got == c.want,
      ("%s: is_ranked %s, wanted %s"):format(c.it.id, tostring(got), tostring(c.want)))
  end
  check.must(idxmod.close(idx))
end

-- `_work.read.key`'s own order-totality: a shorter path is a byte
-- prefix of any longer path sharing its ancestors, so `ranked`'s key
-- is a prefix of `kid`'s, `unranked`'s a prefix of `under_unranked`'s,
-- and sorting every key gives exactly the tree order — a positioned
-- ancestor (`ranked`, key starting "0") before an unpositioned one
-- (`unranked`, key starting "1") at the same level.
local function test_key_orders_the_tree_and_prefixes_its_descendants()
  local board = make({})
  local ranked = make({parent = board.id})
  local unranked = make({parent = board.id})
  board.order = {ranked.id}
  local kid = make({parent = ranked.id})
  local under_unranked = make({parent = unranked.id})
  local items = {board, ranked, unranked, kid, under_unranked}
  local idx = make_index(items)

  local keyed: {string: string} = {}
  for _, it in ipairs(items) do
    keyed[it.id] = check.must(read.key(idx, it.id))
  end
  assert(keyed[board.id] == "", "the board's key is empty, a prefix of every other")
  assert(keyed[kid.id]:sub(1, #keyed[ranked.id]) == keyed[ranked.id]
    and keyed[kid.id] ~= keyed[ranked.id],
    "ranked's key is a strict prefix of its child's own")
  assert(keyed[under_unranked.id]:sub(1, #keyed[unranked.id]) == keyed[unranked.id]
    and keyed[under_unranked.id] ~= keyed[unranked.id],
    "unranked's key is a strict prefix of its child's own")
  assert(keyed[ranked.id] < keyed[unranked.id],
    "a positioned outcome sorts before an unpositioned one")

  local want_ids = {board.id, ranked.id, kid.id, unranked.id, under_unranked.id}
  local by_key: {item.Item} = {}
  for _, it in ipairs(items) do
    by_key[#by_key + 1] = it
  end
  table.sort(by_key, function(a: item.Item, b: item.Item): boolean
      return keyed[a.id] < keyed[b.id]
    end)
  local got_ids: {string} = {}
  for _, it in ipairs(by_key) do
    got_ids[#got_ids + 1] = it.id
  end
  assert(table.concat(got_ids, " ") == table.concat(want_ids, " "),
    ("got:  %s\nwant: %s"):format(table.concat(got_ids, " "), table.concat(want_ids, " ")))
  check.must(idxmod.close(idx))
end

--- `depth` containers under `parent`, each the next one's parent, then
--- one workable leaf under the last — the deep-chain fixture shared by
--- the queue-fallback and `_work.read_structure_test`'s deep-chain test.
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

-- A chain past `rank_path`'s 16-hop bound carries no row there: the
-- leaf reads unranked with the one-field fallback key ("1" plus its
-- own id), the same total-order rule an ordinary unpositioned field
-- follows, and it still queues — the only workable item on this
-- board, since every container above it has exactly one open child.
local function test_a_too_deep_chain_falls_back_to_its_own_id()
  local board = make({})
  local outcome = make({parent = board.id})
  board.order = {outcome.id}
  -- 15 containers puts the leaf at depth 17 from the board (outcome at
  -- depth 1) — one past the 16-hop bound.
  local chain, leaf = make_chain(outcome.id, 15)
  local items: {item.Item} = {board, outcome}
  for _, it in ipairs(chain) do
    items[#items + 1] = it
  end
  local idx = make_index(items)

  local got_ranked = check.must(read.is_ranked(idx, leaf.id))
  assert(got_ranked == false, "past the bound, unranked")
  local got_key = check.must(read.key(idx, leaf.id))
  assert(got_key == "1" .. leaf.id,
    ("%s: got %s, wanted the one-field fallback"):format(leaf.id, got_key))

  local got_rows = check.must(read.queue(idx))
  assert(#got_rows == 1 and got_rows[1].id == leaf.id
    and got_rows[1].stage == flow.STAGE_TODO,
    "the leaf is the board's only workable item")
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

-- `board`: the one parentless item, chosen deterministically (lowest
-- id) on a broken tree carrying more than one.
local function test_board_names_the_one_parentless_item()
  local board = make({})
  local outcome = make({parent = board.id})
  local idx = make_index({board, outcome})
  assert(check.must(read.board(idx)) == board.id, "the board's own id")
  check.must(idxmod.close(idx))
end

local function test_board_is_nil_when_none_is_filed()
  local idx = make_index({})
  local got, err = read.board(idx)
  assert(got == nil and err == "", "no board, no error — nothing is filed yet")
  check.must(idxmod.close(idx))
end

-- `stale`: a claim or review claim past its lease
-- (`_work.health.LEASE_S`/`REVIEW_LEASE_S`), from `items.touched_at` —
-- exercised through `_work.index`'s own load, which writes a caller's
-- `touched_at` straight into the row (no separate lease-hydration
-- path to fake here).
local function test_stale_holds_claims_and_reviews_past_their_lease()
  local board = make({})
  local outcome = make({parent = board.id})
  board.order = {outcome.id}
  local now = os.time()
  local fresh_claim = make({parent = outcome.id, claim = "s1"})
  local stale_claim = make({parent = outcome.id, claim = "s2"})
  local fresh_review = make({parent = outcome.id, pr = 3, reviewer = "r1"})
  local stale_review = make({parent = outcome.id, pr = 4, reviewer = "r2"})
  local idx = check.must(idxmod.open(
      {board, outcome, fresh_claim, stale_claim, fresh_review, stale_review}))
  check.must(idx.db:exec("UPDATE items SET touched_at = ? WHERE id = ?",
      {now, fresh_claim.id}))
  check.must(idx.db:exec("UPDATE items SET touched_at = ? WHERE id = ?",
      {now - 5 * 3600, stale_claim.id}))
  check.must(idx.db:exec("UPDATE items SET touched_at = ? WHERE id = ?",
      {now, fresh_review.id}))
  check.must(idx.db:exec("UPDATE items SET touched_at = ? WHERE id = ?",
      {now - 2 * 3600, stale_review.id}))
  check.must(index_rank.ensure_views(idx))
  check.must(readddl.ensure_views(idx))

  local rows = check.must(read.stale(idx))
  local by_id: {string: read.StaleRow} = {}
  for _, r in ipairs(rows) do
    by_id[r.id] = r
  end
  assert(by_id[fresh_claim.id] == nil, "a fresh claim is not stale")
  assert(by_id[stale_claim.id] ~= nil and by_id[stale_claim.id].kind == "claim",
    "a claim past its 4-hour lease is stale")
  assert(by_id[fresh_review.id] == nil, "a fresh review claim is not stale")
  assert(by_id[stale_review.id] ~= nil and by_id[stale_review.id].kind == "review",
    "a review claim past its 1-hour lease is stale")
  check.must(idxmod.close(idx))
end
