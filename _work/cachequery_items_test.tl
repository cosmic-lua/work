#!/usr/bin/env cosmic
-- `_work.cachequery.items`'s hydration against `store.list`'s fresh git
-- read: field-for-field, item-for-item, IN ORDER — the differential
-- proof behind `_work/gitshow.tl`'s and `_work/gitview.tl`'s switch to
-- the cache's own SQL rows, committed rather than the throwaway script
-- that first checked it against the production board (937 items, 0
-- mismatches). Exercises every field that check covered on a small
-- hand-built fixture: multiple `beats`/`blocked_by` edges with reasons,
-- an `other_edges` kind, `builders`/`speccers` (order matters there —
-- oldest first — unlike the edge sets, which do not), and a held root.

local cache = require("_work.cache")
local cachequery = require("_work.cachequery")
local check = require("cosmic.check")
local fixture = require("_work.fixture")
local item = require("_work.item")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

local init_state_repo = fixture.init_state_repo
local file_item = fixture.file_item

--- Every id in `a`, as a membership map — `beats`/`blocked_by` (and
--- `decode_problems`) are sets, never sequences (`_work/itemtree.tl`'s
--- module header), so they compare order-blind.
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
  assert(got.is_held == want.is_held, id8 .. " is_held")
  assert_same_set(want.beats, got.beats, id8 .. " beats")
  assert_same_set(want.blocked_by, got.blocked_by, id8 .. " blocked_by")
  assert_same_order(want.builders, got.builders, id8 .. " builders")
  assert_same_order(want.speccers, got.speccers, id8 .. " speccers")
  local want_reasons = want.block_reason or {}
  local got_reasons = got.block_reason or {}
  for blocker, why in pairs(want_reasons) do
    assert(got_reasons[blocker] == why, id8 .. " block_reason " .. blocker)
  end
  for blocker in pairs(got_reasons) do
    assert(want_reasons[blocker] ~= nil, id8 .. " block_reason " .. blocker .. " unexpected")
  end
  local want_oe = want.other_edges or {}
  local got_oe = got.other_edges or {}
  for kind, idmap in pairs(want_oe) do
    local got_map = got_oe[kind] or {}
    for eid, reason in pairs(idmap) do
      assert(got_map[eid] == reason, id8 .. " other_edges " .. kind .. " " .. eid)
    end
  end
  for kind in pairs(got_oe) do
    assert(want_oe[kind] ~= nil, id8 .. " other_edges " .. kind .. " unexpected")
  end
  assert_same_set(want.decode_problems or {}, got.decode_problems or {},
    id8 .. " decode_problems")
end

local function test_items_matches_store_list_field_for_field_and_in_order()
  local s = init_state_repo("cachequery-items-hydrate")
  local root = file_item(s, "a held outcome", "")
  local leaf1 = file_item(s, "a workable slice", root)
  local leaf2 = file_item(s, "a second slice", root)
  local leaf3 = file_item(s, "a third slice", root)

  local root_it = check.must(store.load(s, root))
  root_it.is_held = true
  assert(storewrite.save(s, root_it, "hold the root"))

  local leaf_it = check.must(store.load(s, leaf1))
  leaf_it.beats = {leaf2, leaf3}
  leaf_it.blocked_by = {leaf2, leaf3}
  leaf_it.block_reason = {[leaf2] = "waiting on design", [leaf3] = "waiting on data"}
  leaf_it.other_edges = {relates = {[leaf2] = "see also"}}
  leaf_it.builders = {"session-a", "session-b"}
  leaf_it.speccers = {"session-c"}
  assert(storewrite.save(s, leaf_it, "hand-edit leaf1 with edges and a roster"))

  local want = check.must(store.list(s))
  local c = check.must(cache.open(s.root))
  local got = check.must(cachequery.items(c))
  assert(check.must(cache.close(c)))

  assert(#want == #got, ("%d vs %d items"):format(#want, #got))
  for i, w in ipairs(want) do
    local g = got[i]
    assert(g.id == w.id, ("order: position %d is %s, want %s"):format(
        i, g.id:sub(1, 8), w.id:sub(1, 8)))
    assert_items_match(w, g)
  end
end
test_items_matches_store_list_field_for_field_and_in_order()
