--- Order-totality fuzz property for `_work.readddl`'s `queue` view, over
--- adversarial item graphs (random parents and `order` lists from a
--- small shared id pool, including stale entries, duplicates, and
--- cycles, plus randomized claim/PR/verdict/lane-repair fields so
--- every stage bucket — accepted, review, rework, building, repair,
--- todo — gets exercised): no Teal oracle stands in for `queue`
--- anymore (`docs/design/read.md`), so what this checks instead is
--- that the view's own SQL `ORDER BY` is a genuine total order and
--- names exactly the board's workable items —
---   every id `queue` returns is distinct;
---   the row count equals a raw, independent count of `workable`;
---   re-sorting the returned rows in Teal by the exact fields the SQL
---   itself ordered by (`stage`, `key`, `id`) changes nothing — the
---   database's own collation and Lua's string comparison agree.
--- The generated graph is length-prefixed into the driver's string
--- input, so a failure still reports a replayable seed and shrinks to
--- a small graph.
--- env: FUZZ_SEED FUZZ_ITERS

local check = require("cosmic.check")
local driver = require("_fuzz.driver")
local idxmod = require("_work.index")
local irank = require("_work.index_rank")
local item = require("_work.item")
local read = require("_work.read")
local readddl = require("_work.readddl")
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

-- Small enough that stale/duplicate order entries and a chain past
-- MAX_DEPTH are all likely within a handful of items.
local MAX_ITEMS < const > = 10
local MAX_ORDER < const > = 5

--- A fixed pool of ids: which items and which order/root-list entries
--- use which is what the generator randomizes.
local ID_POOL < const >: {string} = {"a", "b", "c", "d", "e", "f", "g", "h"}

--- The `verdict` values the schema's own CHECK constraint allows —
--- the only three a generated item may draw.
local VERDICTS < const >: {string} = {"", "accept", "request changes"}

--- Draw a random subset of `pool`, as a list, possibly with repeats.
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
--- from the same pool (itself, a sibling, or a dangling id), an
--- `order` list drawn the same way, and randomized stage-affecting
--- fields. A lane-repair `key`, when drawn, is derived from the item's
--- OWN id ("k-" .. id) rather than drawn independently — two open
--- items sharing a key is refused at load (`one_open_item_per_key`),
--- and a key tied to the id can never collide.
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
  local claim = ""
  if src:int(1, 3) == 1 then
    claim = "s"
  end
  local pr = 0
  if src:int(1, 3) == 1 then
    pr = 1
  end
  local verdict = VERDICTS[src:int(1, #VERDICTS)]
  local key = ""
  if src:int(1, 4) == 1 then
    key = "k-" .. id
  end
  return {
    id = id, title = "x", parent = parent, repo = "", base = "", key = key,
    order = id_list(src, pool),
    claim = claim, builders = {}, speccers = {}, reviewer = "", pr = pr,
    result = "", verdict = verdict, verdict_head = "", verdict_spec = "",
    resolution = "",
  }
end

--- Encode a list of items plus a root list into the driver's string
--- carrier: the pool first, then each item's fields by index into the
--- pool, then the root list the same way.
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
    put(out, it.claim)
    put(out, tostring(it.pr))
    put(out, it.verdict)
    put(out, it.key)
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
  return table.concat(out)
end

--- One decoded graph: the items plus the board's own root list.
local record Graph
  items: {item.Item}
  root_order: {string}
end

--- Decode what `gen_graph` wrote back into a `Graph`.
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
    local claim = take(c)
    local pr_text = take(c)
    local verdict = take(c)
    local key = take(c)
    local norder_text = take(c)
    if parent == nil or claim == nil or pr_text == nil or verdict == nil
    or key == nil or norder_text == nil then
      return nil, "malformed item"
    end
    local pr = math.tointeger(tonumber(pr_text))
    local norder = math.tointeger(tonumber(norder_text))
    if pr == nil or norder == nil then
      return nil, "malformed item counts"
    end
    local order: {string} = {}
    for i = 1, norder do
      local o = take(c)
      if o == nil then
        return nil, "malformed order entry"
      end
      order[i] = o
    end
    if not seen[id] then
      seen[id] = true
      items[#items + 1] = {
        id = id, title = "x", parent = parent, repo = "", base = "",
        key = key, order = order,
        claim = claim, builders = {}, speccers = {},
        reviewer = "", pr = pr, result = "", verdict = verdict,
        verdict_head = "", verdict_spec = "", resolution = "",
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
  return {items = items, root_order = root_order}, ""
end

-- `queue`'s own order must be total, and its rows must name exactly
-- the board's workable items — over every graph this pool can draw:
-- cycles, dangling parents, stale and duplicate order entries, and
-- every stage bucket included.
local function test_queue_is_a_total_order_over_every_workable_item()
  local ok, message = driver.run({
      name = "read_queue_is_a_total_order",
      gen = gen_graph,
      budget = 4000000,
      check = function(input: string): boolean, string
        local g, derr = decode_graph(input)
        if g == nil then
          return false, "generated input did not decode: " .. tostring(derr)
        end
        local items = g.items
        -- Fold the separately drawn root list onto whichever item is
        -- parentless (the board), matching `_work.readddl`'s own
        -- `rank_path` view reading a board's outcome ranking off the
        -- board ITEM's own `order` field.
        for _, it in ipairs(items) do
          if (it.parent or "") == "" then
            it.order = g.root_order
            break
          end
        end

        local idx, oerr = idxmod.open(items)
        if idx == nil then
          return false, "index.open failed: " .. tostring(oerr)
        end
        local rvok, rverr = irank.ensure_views(idx)
        if not rvok then
          local _c, _ce = idxmod.close(idx)
          return false, "ensure_views failed: " .. tostring(rverr)
        end
        local rdok, rderr = readddl.ensure_views(idx)
        if not rdok then
          local _c, _ce = idxmod.close(idx)
          return false, "readddl.ensure_views failed: " .. tostring(rderr)
        end

        local got_rows, qerr = read.queue(idx)
        if got_rows == nil then
          local _c, _ce = idxmod.close(idx)
          return false, "read.queue failed: " .. tostring(qerr)
        end
        local wrow, werr = idx.db:query_one("SELECT COUNT(*) AS n FROM workable")
        local _c, _ce = idxmod.close(idx)
        if wrow == nil then
          return false, "counting workable failed: " .. tostring(werr)
        end
        local want_n = math.tointeger(wrow.n as number) or -1 -- cast: from any (sqlite row)

        if #got_rows ~= want_n then
          return false, ("queue returned %d row(s), workable has %d")
          :format(#got_rows, want_n)
        end
        local seen: {string: boolean} = {}
        for _, r in ipairs(got_rows) do
          if seen[r.id] then
            return false, "queue named the same id twice: " .. r.id
          end
          seen[r.id] = true
        end

        -- The rows re-sorted, in Teal, by the exact fields the view's
        -- own `ORDER BY` used: if this changes nothing, the database's
        -- collation and Lua's `<` agree, and the order is total.
        local resorted: {read.QueueRow} = {}
        for _, r in ipairs(got_rows) do
          resorted[#resorted + 1] = r
        end
        table.sort(resorted, function(a: read.QueueRow, b: read.QueueRow): boolean
            if a.stage ~= b.stage then
              return a.stage < b.stage
            end
            if a.key ~= b.key then
              return a.key < b.key
            end
            return a.id < b.id
          end)
        for i, r in ipairs(got_rows) do
          if resorted[i].id ~= r.id then
            return false, ("queue's own order is not total: position %d was %s, "
              .. "a Teal re-sort of the same rows wants %s"):format(
              i, r.id, resorted[i].id)
          end
        end
        return true
      end,
    })
  check.truthy(ok, message)
end
