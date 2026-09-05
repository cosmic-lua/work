--- Fuzz properties for `_work.rank`'s pure rank-path derivation over an
--- ADVERSARIAL item graph: random parents and random `order` lists
--- (including stale entries — an id no longer a child — and duplicate
--- ones), drawn from a small shared id pool the same way
--- `_fuzz/priority_fuzz_test.tl` builds its adversarial graphs, plus a
--- random board root list drawn the same way. This is exactly the
--- shape `gitboard fsck` exists to catch, and exactly what a
--- hand-edited or corrupted commit can hand back to a live read.
---   sorted is a total order: antisymmetric and transitive on sampled
---   triples, over any graph this pool can draw;
---   sorted agrees with key's lexicographic order on sampled pairs;
---   positions/sorted/key are identical across two runs over the same
---   generated input, so no table-iteration order leaks into a render.
--- The generated graph is length-prefixed into the driver's string
--- input the way `_fuzz/priority_fuzz_test.tl`'s is, so a failure
--- still reports a replayable seed and shrinks to a small graph.
--- env: FUZZ_SEED FUZZ_ITERS

local check = require("cosmic.check")
local driver = require("_fuzz.driver")
local item = require("_work.item")
local rank = require("_work.rank")
local source = require("_fuzz.source")

--- Write one length-prefixed field: `<n>:<bytes>`.
--- @param out {string} Accumulator to append to
--- @param s string The field
local function put(out: {string}, s: string)
  out[#out + 1] = tostring(#s) .. ":" .. s
end

--- A cursor over a length-prefixed blob `put` wrote.
local record Cursor
  blob: string
  pos: integer
end

--- Read one field `put` wrote, advancing the cursor.
--- @param c Cursor The cursor
--- @return string | nil The field
--- @return string Error message, when malformed
local function take(c: Cursor): string | nil, string
  local colon = c.blob:find(":", c.pos, true)
  if not colon then
    return nil, "no length prefix at " .. tostring(c.pos)
  end
  local size = math.tointeger(tonumber(c.blob:sub(c.pos, colon - 1)))
  if not size then
    return nil, "bad length at " .. tostring(c.pos)
  end
  local value = c.blob:sub(colon + 1, colon + size)
  if #value ~= size then
    return nil, "short read at " .. tostring(c.pos)
  end
  c.pos = colon + 1 + size
  return value
end

-- Small enough that stale and duplicate order entries, and a chain
-- past MAX_DEPTH, are all likely within a handful of items, and small
-- enough that a shrunk failure is readable by eye.
local MAX_ITEMS < const > = 10
local MAX_ORDER < const > = 5

--- A fixed pool of ids: which items and which order/root-list entries
--- use which is what the generator randomizes, so the ids themselves
--- are deterministic labels, not a seeded draw — reusing one across
--- items is what makes a parent chain cyclic, and some are never
--- assigned to any item at all, which is what makes an order entry
--- stale or a root entry name nothing real.
local ID_POOL < const >: {string} = {"a", "b", "c", "d", "e", "f", "g", "h"}

--- Draw a random subset of `pool`, as a list, possibly with repeats —
--- exactly the shape a stale or duplicate `order`/root-list entry
--- takes.
--- @param src source.Recorder The source to draw from
--- @param pool {string} The ids to draw from
--- @return {string} The drawn ids
local function id_list(src: source.Recorder, pool: {string}): {string}
  local out: {string} = {}
  for _ = 1, src:int(0, MAX_ORDER) do
    out[#out + 1] = pool[src:int(1, #pool)]
  end
  return out
end

--- Build one adversarial item: a real id from the pool, a parent drawn
--- from the SAME pool (so it may be itself, a sibling, or a dangling
--- id), and an `order` list drawn the same way.
--- @param src source.Recorder The source to draw from
--- @param pool {string} The id pool
--- @param id string This item's own id (also in the pool)
--- @return item.Item The item
local function adversarial_item(src: source.Recorder, pool: {string},
    id: string): item.Item
  local parent = ""
  if src:int(1, 3) ~= 1 then
    parent = pool[src:int(1, #pool)]
  end
  return {
    id = id, title = "x", parent = parent, repo = "", base = "", key = "",
    order = id_list(src, pool),
    claim = "", builders = {}, speccers = {}, reviewer = "", pr = 0,
    result = "", verdict = "", verdict_head = "", verdict_spec = "",
    resolution = "",
  }
end

--- Encode a list of items plus a root list into the driver's string
--- carrier: the pool first (so a dangling id used only as an order
--- entry still shrinks consistently), then each item's parent/order by
--- index into the pool, then the root list the same way.
--- @param src source.Recorder The source to draw from
--- @return string The encoded graph
local function gen_graph(src: source.Recorder): string
  local pool = ID_POOL
  local out: {string} = {}
  for _, id in ipairs(pool) do
    put(out, id)
  end
  put(out, "") -- pool terminator
  for _ = 1, src:int(1, MAX_ITEMS) do
    local id = pool[src:int(1, #pool)]
    local it = adversarial_item(src, pool, id)
    put(out, id)
    put(out, it.parent)
    put(out, tostring(#it.order))
    for _, o in ipairs(it.order) do
      put(out, o)
    end
  end
  put(out, "") -- items terminator (an id, but "" is never in the pool)
  local root_order = id_list(src, pool)
  put(out, tostring(#root_order))
  for _, r in ipairs(root_order) do
    put(out, r)
  end
  -- Three draws into the (deduplicated) item id set, sampling one
  -- triple to check antisymmetry/transitivity against; out-of-range
  -- draws are reduced modulo the eventual item count on decode.
  put(out, tostring(src:int(0, MAX_ITEMS - 1)))
  put(out, tostring(src:int(0, MAX_ITEMS - 1)))
  put(out, tostring(src:int(0, MAX_ITEMS - 1)))
  return table.concat(out)
end

--- One decoded graph: the items, the board's root list, and three
--- sample indices (0-based, into the decoded item list once
--- deduplicated by id) to check transitivity against.
local record Graph
  items: {item.Item}
  root_order: {string}
  sample: {integer}
end

--- Decode what `gen_graph` wrote back into a `Graph`. Total over
--- anything `take` accepts: a short or malformed blob returns nil
--- rather than throwing, exactly like every other decoder this tree
--- fuzzes.
--- @param blob string The encoded graph
--- @return Graph | nil The graph
--- @return string Error message, when malformed
local function decode_graph(blob: string): Graph | nil, string
  local c: Cursor = {blob = blob, pos = 1}
  while true do
    local id, err = take(c)
    if id == nil then
      return nil, "malformed pool: " .. tostring(err)
    end
    if id == "" then
      break
    end
  end
  local seen: {string: boolean} = {}
  local items: {item.Item} = {}
  while true do
    local id = take(c)
    if id == nil or id == "" then
      break
    end
    local parent = take(c)
    if parent == nil then
      return nil, "malformed item"
    end
    local norder_text = take(c)
    local norder = norder_text and math.tointeger(tonumber(norder_text))
    if norder == nil then
      return nil, "malformed order count"
    end
    local order: {string} = {}
    for i = 1, norder do
      local o = take(c)
      if o == nil then
        return nil, "malformed order entry"
      end
      order[i] = o
    end
    -- One item per id: a repeated draw overwrites the earlier one
    -- rather than filing a duplicate id, which `item.decode` refuses
    -- to round-trip meaningfully anyway.
    if not seen[id] then
      seen[id] = true
      items[#items + 1] = {
        id = id, title = "x", parent = parent, repo = "", base = "",
        key = "", order = order,
        claim = "", builders = {}, speccers = {},
        reviewer = "", pr = 0, result = "", verdict = "", verdict_head = "",
        verdict_spec = "", resolution = "",
      }
    end
  end
  local nroot_text = take(c)
  local nroot = nroot_text and math.tointeger(tonumber(nroot_text))
  if nroot == nil then
    return nil, "malformed root count"
  end
  local root_order: {string} = {}
  for i = 1, nroot do
    local r = take(c)
    if r == nil then
      return nil, "malformed root entry"
    end
    root_order[i] = r
  end
  local sample: {integer} = {}
  for i = 1, 3 do
    local s = take(c)
    local sv = s and math.tointeger(tonumber(s))
    if sv == nil then
      return nil, "malformed sample index"
    end
    sample[i] = sv
  end
  return {items = items, root_order = root_order, sample = sample}
end

--- Whether `a` sorts strictly before `b`: `rank.sorted` on just the
--- two of them names `a` first. The public surface this test is
--- allowed to reach into, so a property here never assumes anything
--- about `_work.rank`'s internals.
--- @param ranks {string: rank.Rank} Rank by item id
--- @param a item.Item One item
--- @param b item.Item The other
--- @return boolean True when a sorts before b
local function sorts_before(ranks: {string: rank.Rank}, a: item.Item,
    b: item.Item): boolean
  local pair: {item.Item} = {a, b}
  return rank.sorted(pair, ranks)[1].id == a.id
end

-- sorted must be total (antisymmetric, transitive), agree with key,
-- and reproduce byte-identical output across two independent runs
-- over ANY graph this pool can draw — cycles, dangling parents, stale
-- and duplicate order entries included.
local function test_rank_is_a_total_deterministic_order()
  local ok, message = driver.run({
      name = "rank_total_order",
      gen = gen_graph,
      budget = 2000000,
      check = function(input: string): boolean, string
        local g, derr = decode_graph(input)
        if g == nil then
          return false, "generated input did not decode: " .. tostring(derr)
        end
        -- `rank.positions` reads a board's outcome ranking off the
        -- board ITEM's own `order` field now, not a second argument:
        -- fold the generator's separately drawn root list onto
        -- whichever item in the graph is parentless (the board, in
        -- the new model) — a no-op draw when nothing in the graph is.
        for _, it in ipairs(g.items) do
          if (it.parent or "") == "" then
            it.order = g.root_order
            break
          end
        end
        local ranks = rank.positions(g.items)
        if type(ranks) ~= "table" then
          return false, "positions did not return a table"
        end
        local sorted1 = rank.sorted(g.items, ranks)
        if #sorted1 ~= #g.items then
          return false, "sorted dropped or added items"
        end

        -- Identical across two runs: neither positions nor sorted may
        -- leak table-iteration order into the render.
        local ranks_again = rank.positions(g.items)
        local sorted_again = rank.sorted(g.items, ranks_again)
        for i, it in ipairs(sorted1) do
          if sorted_again[i].id ~= it.id then
            return false, "sorted is not identical across two runs"
          end
          if rank.key(ranks, it.id) ~= rank.key(ranks_again, it.id) then
            return false, "key is not identical across two runs"
          end
        end

        -- key agrees with sorted: walking sorted1 in order, each key
        -- must be >= the one before it.
        local prev_key: string | nil = nil
        for _, it in ipairs(sorted1) do
          local k = rank.key(ranks, it.id)
          if prev_key ~= nil and k < prev_key then
            return false, "key order disagrees with sorted order"
          end
          prev_key = k
        end

        -- Antisymmetry and transitivity on the sampled triple.
        local n = #g.items
        if n >= 2 then
          local ia = 1 + (g.sample[1] % n)
          local ib = 1 + (g.sample[2] % n)
          local ic = 1 + (g.sample[3] % n)
          local a, b, cc = g.items[ia], g.items[ib], g.items[ic]
          if a.id ~= b.id then
            local ab = sorts_before(ranks, a, b)
            local ba = sorts_before(ranks, b, a)
            if ab == ba then
              return false, "antisymmetry failed between two distinct items"
            end
          end
          if a.id ~= b.id and b.id ~= cc.id and a.id ~= cc.id then
            local ab = sorts_before(ranks, a, b)
            local bc = sorts_before(ranks, b, cc)
            local ac = sorts_before(ranks, a, cc)
            if ab and bc and not ac then
              return false, "transitivity failed: a<b<c but not a<c"
            end
            if (not ab) and (not bc) and ac then
              return false, "transitivity failed: c<b<a but not c<a"
            end
          end
        end
        return true
      end,
    })
  check.truthy(ok, message)
end
