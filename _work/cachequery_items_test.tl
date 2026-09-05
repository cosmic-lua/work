#!/usr/bin/env cosmic
-- `_work.cachequery.items`'s hydration against `store.list`'s fresh git
-- read: field-for-field, item-for-item, IN ORDER — the differential
-- proof behind `_work/gitshow.tl`'s and `_work/gitview.tl`'s switch to
-- the cache's own SQL rows, committed rather than the throwaway script
-- that first checked it against the production board (937 items, 0
-- mismatches). Exercises every field that check covered on a small
-- hand-built fixture: `builders`/`speccers` (order matters there —
-- oldest first), and one item carrying an edge kind this build does
-- not interpret — present on the git-truthed side and absent on the
-- cache-hydrated one, since the cache carries no edge kind at all.

local cache = require("_work.cache")
local cachequery = require("_work.cachequery")
local check = require("cosmic.check")
local fixture = require("_work.fixture")
local item = require("_work.item")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

local init_state_repo = fixture.init_state_repo
local file_item = fixture.file_item

--- Every id in `a`, as a membership map (`decode_problems` is a set,
--- never a sequence), so it compares order-blind.
--- @param a {string} The ids
--- @return {string: boolean} Membership by id
local function as_set(a: {string}): {string: boolean}
  local out: {string: boolean} = {}
  for _, id in ipairs(a) do
    out[id] = true
  end
  return out
end

--- `want` and `got` name the same ids, order-blind.
--- @param want {string} The `store.list` side
--- @param got {string} The `cachequery.items` side
--- @param label string What is being compared, for the failure message
local function assert_same_set(want: {string}, got: {string}, label: string)
  assert(#want == #got, ("%s: %d vs %d"):format(label, #want, #got))
  local seen = as_set(want)
  for _, id in ipairs(got) do
    assert(seen[id], ("%s: %s unexpected"):format(label, id))
  end
end

--- `want` and `got` name the same ids in the SAME order — `builders`/
--- `speccers` are "oldest first" rosters, not sets: the cache's own
--- `seq` column exists to keep this order across a patch, and this is
--- what proves the hydration keeps it too.
--- @param want {string} The `store.list` side
--- @param got {string} The `cachequery.items` side
--- @param label string What is being compared, for the failure message
local function assert_same_order(want: {string}, got: {string}, label: string)
  assert(#want == #got, ("%s: %d vs %d"):format(label, #want, #got))
  for i, name in ipairs(want) do
    assert(got[i] == name, ("%s[%d]: %s vs %s"):format(label, i, got[i], name))
  end
end

--- One item's fields, field-for-field, between `store.list`'s decode
--- and `cachequery.items`'s hydration.
--- @param want item.Item The `store.list` item
--- @param got item.Item The `cachequery.items` item
local function assert_items_match(want: item.Item, got: item.Item)
  local id8 = want.id:sub(1, 8)
  assert(got.title == want.title, id8 .. " title")
  assert(got.parent == want.parent, id8 .. " parent")
  assert(got.repo == want.repo, id8 .. " repo")
  assert(got.base == want.base, id8 .. " base")
  assert(got.key == want.key, id8 .. " key")
  assert(got.claim == want.claim, id8 .. " claim")
  assert(got.reviewer == want.reviewer, id8 .. " reviewer")
  assert(got.pr == want.pr, id8 .. " pr")
  assert(got.result == want.result, id8 .. " result")
  assert(got.verdict == want.verdict, id8 .. " verdict")
  assert(got.verdict_head == want.verdict_head, id8 .. " verdict_head")
  assert(got.verdict_spec == want.verdict_spec, id8 .. " verdict_spec")
  assert(got.resolution == want.resolution, id8 .. " resolution")
  assert_same_order(want.order, got.order, id8 .. " order")
  assert_same_order(want.builders, got.builders, id8 .. " builders")
  assert_same_order(want.speccers, got.speccers, id8 .. " speccers")
  assert_same_set(want.decode_problems or {}, got.decode_problems or {},
    id8 .. " decode_problems")
end

local function test_items_matches_store_list_field_for_field_and_in_order()
  local s = init_state_repo("cachequery-items-hydrate")
  local root = file_item(s, "an outcome", "")
  local leaf1 = file_item(s, "a workable slice", root)
  local leaf2 = file_item(s, "a second slice", root)
  local leaf3 = file_item(s, "a third slice", root)

  local root_it = check.must(store.load(s, root))
  root_it.order = {leaf2, leaf3, leaf1}
  assert(storewrite.save(s, root_it, "rank the children"))
  assert(storewrite.save_root_order(s, {root}, "rank the roots"))

  local leaf_it = check.must(store.load(s, leaf1))
  leaf_it.other_edges = {relates = {[leaf2] = "see also"}}
  leaf_it.builders = {"session-a", "session-b"}
  leaf_it.speccers = {"session-c"}
  assert(storewrite.save(s, leaf_it, "hand-edit leaf1 with an edge and a roster"))

  local want = check.must(store.list(s))
  local want_root_order = store.root_order(s)
  local c = check.must(cache.open(s.root))
  local got = check.must(cachequery.items(c))
  local got_root_order = check.must(cachequery.root_order(c))
  assert(check.must(cache.close(c)))

  assert(#want == #got, ("%d vs %d items"):format(#want, #got))
  for i, w in ipairs(want) do
    local g = got[i]
    assert(g.id == w.id, ("order: position %d is %s, want %s"):format(
        i, g.id:sub(1, 8), w.id:sub(1, 8)))
    assert_items_match(w, g)
  end
  assert_same_order(want_root_order, got_root_order, "root_order")

  -- The one field this differential deliberately does NOT match:
  -- `store.list`'s fresh git read carries leaf1's edge kind
  -- (`item.Item.other_edges`), but the cache's schema has no `edges`
  -- table at all, so the hydrated side is always nil.
  local leaf1_want, leaf1_got: item.Item, item.Item
  for i, w in ipairs(want) do
    if w.id == leaf1 then
      leaf1_want, leaf1_got = w, got[i]
    end
  end
  assert(leaf1_want ~= nil, "leaf1 is on the git-truthed side")
  local want_edges = leaf1_want.other_edges
  assert(want_edges ~= nil and want_edges.relates ~= nil
    and want_edges.relates[leaf2] == "see also",
    "the git-truthed side carries the edge")
  assert(leaf1_got ~= nil and leaf1_got.other_edges == nil,
    "the cache-hydrated side carries no edge kind at all")
end
test_items_matches_store_list_field_for_field_and_in_order()
