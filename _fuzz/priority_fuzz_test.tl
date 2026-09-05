--- Fuzz properties for `_work.priority` and `_work.flow`'s pure graph
--- reads (`positions`, `cycle_problems`, `graph_problems`) over an
--- ADVERSARIAL item graph: random parents, `beats` and `blocked_by`
--- edges drawn from a small shared id pool, deliberately including
--- self-references, dangling ids and cycles — exactly the shape
--- `gitboard fsck` exists to catch, and exactly what a hand-edited or
--- corrupted commit can hand back to a live read. Every board-rendering
--- verb (`show`, `next`) calls these on every run, so a graph that hangs
--- or crashes them is a wedged board, not a bad answer.
---   positions/cycle_problems/graph_problems are total (never throw)
---   and terminate within budget over any graph this pool can draw.
--- The generated graph is length-prefixed into the driver's string
--- input the way `_fuzz/url_fuzz_test.tl`'s query map is, so a failure
--- still reports a replayable seed and shrinks to a small graph.
--- env: FUZZ_SEED FUZZ_ITERS

local check = require("cosmic.check")
local driver = require("_fuzz.driver")
local flow = require("_work.flow")
local item = require("_work.item")
local prio = require("_work.priority")
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

-- Small enough that a self-reference, a dangling reference and a cycle
-- are all likely within a handful of items, and small enough that a
-- shrunk failure is readable by eye.
local MAX_ITEMS < const > = 10
local MAX_EDGES < const > = 4

--- A fixed pool of ids: which items and edges use which is what the
--- generator randomizes, so the ids themselves are deterministic
--- labels, not a seeded draw — reusing one across items is what makes
--- edges collide and cycle, and some are never assigned to any item at
--- all, which is what makes an edge dangling.
local ID_POOL < const >: {string} = {"a", "b", "c", "d", "e", "f"}

--- Draw a random subset of `pool`, as a list, possibly with repeats —
--- `item.problems`' own dedup is not asked here, since this is testing
--- what a graph looks like BEFORE that gate, not after it.
--- @param src source.Recorder The source to draw from
--- @param pool {string} The ids to draw from
--- @return {string} The drawn ids
local function edge_list(src: source.Recorder, pool: {string}): {string}
  local out: {string} = {}
  for _ = 1, src:int(0, MAX_EDGES) do
    out[#out + 1] = pool[src:int(1, #pool)]
  end
  return out
end

--- Build one adversarial item: a real id from the pool, a parent drawn
--- from the SAME pool (so it may be itself, a sibling, or a dangling
--- id), and beats/blocked_by drawn the same way. Resolution is drawn
--- too, since is_open gates several reads here.
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
  local resolution = ""
  if src:int(1, 4) == 1 then
    resolution = "completed"
  end
  return {
    id = id, title = "x", parent = parent, repo = "", base = "", key = "",
    beats = edge_list(src, pool), blocked_by = edge_list(src, pool),
    block_reason = {}, claim = "", builders = {}, speccers = {},
    reviewer = "", pr = 0, result = "", verdict = "", verdict_head = "",
    verdict_spec = "", resolution = resolution,
  }
end

--- Encode a list of items into the driver's string carrier: the pool
--- first (so a dangling id used only as an edge target still shrinks
--- consistently), then each item's parent/beats/blocked_by/resolution
--- by index into the pool.
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
    put(out, it.resolution)
    put(out, tostring(#it.beats))
    for _, b in ipairs(it.beats) do
      put(out, b)
    end
    put(out, tostring(#it.blocked_by))
    for _, b in ipairs(it.blocked_by) do
      put(out, b)
    end
  end
  put(out, "") -- items terminator (an id, but "" is never in the pool)
  return table.concat(out)
end

--- Decode what `gen_graph` wrote back into an item list. Total over
--- anything `take` accepts: a short or malformed blob returns nil
--- rather than throwing, exactly like every other decoder this tree
--- fuzzes.
--- @param blob string The encoded graph
--- @return {item.Item} | nil The items
--- @return string Error message, when malformed
local function decode_graph(blob: string): {item.Item} | nil, string
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
  local items: {item.Item} = {}
  while true do
    local id = take(c)
    if id == nil or id == "" then
      break
    end
    local parent = take(c)
    local resolution = take(c)
    if parent == nil or resolution == nil then
      return nil, "malformed item"
    end
    local nbeats_text = take(c)
    local nbeats = nbeats_text and math.tointeger(tonumber(nbeats_text))
    if nbeats == nil then
      return nil, "malformed beats count"
    end
    local beats: {string} = {}
    for i = 1, nbeats do
      local b = take(c)
      if b == nil then
        return nil, "malformed beats entry"
      end
      beats[i] = b
    end
    local nblocked_text = take(c)
    local nblocked = nblocked_text and math.tointeger(tonumber(nblocked_text))
    if nblocked == nil then
      return nil, "malformed blocked_by count"
    end
    local blocked_by: {string} = {}
    for i = 1, nblocked do
      local b = take(c)
      if b == nil then
        return nil, "malformed blocked_by entry"
      end
      blocked_by[i] = b
    end
    items[#items + 1] = {
      id = id, title = "x", parent = parent, repo = "", base = "", key = "",
      beats = beats, blocked_by = blocked_by, block_reason = {}, claim = "",
      builders = {}, speccers = {}, reviewer = "", pr = 0, result = "",
      verdict = "", verdict_head = "", verdict_spec = "", resolution = resolution,
    }
  end
  return items
end

-- positions/cycle_problems/graph_problems must never throw and must
-- terminate within budget over ANY item list this pool can generate —
-- self-references, dangling ids and beats/blocked_by cycles included.
local function test_graph_reads_total()
  local ok, message = driver.run({
      name = "graph_reads_total",
      gen = gen_graph,
      -- Every property here is pure Lua over a tiny (<=10 item) graph;
      -- a genuine infinite loop is the only way to exceed a generous
      -- budget, so this is a strict tightening, not slack for a slow
      -- but correct run.
      budget = 2000000,
      check = function(input: string): boolean, string
        local items, derr = decode_graph(input)
        if items == nil then
          return false, "generated input did not decode: " .. tostring(derr)
        end
        local pos = prio.positions(items)
        if type(pos) ~= "table" then
          return false, "positions did not return a table"
        end
        local cycles = prio.cycle_problems(items)
        if type(cycles) ~= "table" then
          return false, "cycle_problems did not return a table"
        end
        local graph = flow.graph_problems(items)
        if type(graph) ~= "table" then
          return false, "graph_problems did not return a table"
        end
        return true
      end,
    })
  check.truthy(ok, message)
end
