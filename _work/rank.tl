--- An item's rank is a path: its position among its siblings at each
--- level down from the board, the one parentless item. Rank among
--- siblings is a position in a list the parent holds; siblings not in
--- the list follow it, by age. An outcome the board's list does not
--- position, and everything under it, is triage.
---
--- This module derives that path for every item and compares two
--- paths against each other; it holds no store and no git, and reads
--- nothing but the item list handed to it — the board is found IN
--- that list (the one item with no parent), never passed separately.
--- The board's own level contributes nothing to a path — every item
--- shares it — so a path starts at the outcome: walking down from
--- there, at each level an ancestor's position is looked up in the id
--- list its OWN parent holds (`Item.order` — the board's own `order`
--- for the outcome level, since the board holds its children's list
--- exactly as any other parent holds its own) — dense over entries
--- that actually name a current child of that parent, so an id left
--- behind by a move (no longer a real child) is skipped rather than
--- consuming a slot, and two identical entries consume only one. An id
--- absent from its parent's list is unranked among its siblings: it
--- still gets a level in the path, just with no position at that
--- level. The board item itself gets a `Rank` whose chain is empty,
--- which sorts before every other chain (a strict prefix of all of
--- them) — fitting, since nothing outranks the board, though nothing
--- ever queues it either. Whether an item is ranked at all is never
--- stored on the `Rank` — it is the empty chain (the board) or the
--- outcome level's own position (`chain[1]`), so `is_ranked` derives it
--- from the chain that is already there.
---
--- Comparing two items walks both paths from the outcome level down to
--- the first level where they name different ancestors. There, a
--- positioned ancestor sorts before an unpositioned one; two
--- positioned ancestors sort by position; two unpositioned ones fall
--- back to age (id order — KSUIDs sort by creation time) or, when a
--- session seed is given, a hash of the seed and the ancestor's id, so
--- concurrent sessions fan out across ties instead of converging on
--- the same one. When one path is a strict prefix of the other, the
--- shorter one — the ancestor — sorts first.
---
--- Pure functions over a list of items: no store, no network. The
--- module deliberately requires only `_work.item`, so `_work.flow` may
--- build on it without a cycle — `is_outcome` lives in `_work.flow`
--- since it needs more context than one item carries (its own parent's
--- identity), but whether an item is the board (`item.is_parentless`)
--- needs no such help.
local item = require("_work.item")

local type Item = item.Item
local type Index = item.Index

--- One ancestor's position in ITS OWN parent's list — one entry of a
--- `Rank.chain`.
local record Level
  --- The ancestor's id.
  id: string
  --- Its dense position among its parent's real, listed children;
  --- -1 when it names no entry in that list (unranked at this level).
  position: integer
end

--- One item's rank: the outcome-down path a comparison walks.
local record Rank
  --- The ancestor chain from the outcome down to this item, inclusive
  --- — empty for the board itself, otherwise always at least one
  --- entry (the item itself), even when the walk to the board failed
  --- (see `positions`).
  chain: {Level}
end

--- Positions by parent id, memoized: every sibling under one parent
--- shares the same dense map (the board's own id is an ordinary key
--- here too, since its `order` is an ordinary item field), so this is
--- built once per parent no matter how many of its descendants are
--- ranked.
local type PosMap = {string: integer}
local type PosCache = {string: PosMap}

--- Whether `id` is a CURRENT real child of `parent_id`: it exists and
--- its own `parent` field still names `parent_id`. A stale list entry
--- — left over after a move — names a real item that no longer
--- qualifies, and is skipped rather than error, exactly like a
--- dangling `beats`/`blocked_by` id elsewhere in this tree.
--- @param index Index Items by id
--- @param parent_id string The parent's id
--- @param id string The candidate child id
--- @return boolean True when it is a real, current child
local function is_real_child(index: Index, parent_id: string, id: string):
  boolean
  local child = index[id]
  return child ~= nil and (child.parent or "") == parent_id
end

--- One parent's dense position map: each id in `order_list` that names
--- a real current child of `parent_id`, numbered 0, 1, 2, ... in the
--- order it first appears. A stale entry consumes no number; a
--- repeated entry keeps the number its first appearance got.
--- @param order_list {string} The parent's ranked-children list
--- @param index Index Items by id
--- @param parent_id string The parent's id
--- @return PosMap Dense position by child id
local function dense_positions(order_list: {string}, index: Index,
    parent_id: string): PosMap
  local out: PosMap = {}
  local next_position = 0
  for _, id in ipairs(order_list) do
    if out[id] == nil and is_real_child(index, parent_id, id) then
      out[id] = next_position
      next_position = next_position + 1
    end
  end
  return out
end

--- `dense_positions` for one parent, memoized in `cache`. The board's
--- own `order` is read off `index` exactly as any other parent's is —
--- it holds its outcomes' list the same way any item holds its
--- children's.
--- @param parent_id string The parent's id
--- @param index Index Items by id
--- @param cache PosCache Memo, filled in place
--- @return PosMap Dense position by child id
local function positions_for(parent_id: string, index: Index,
    cache: PosCache): PosMap
  local cached = cache[parent_id]
  if cached ~= nil then
    return cached
  end
  local parent = index[parent_id]
  local order_list = (parent ~= nil and parent.order) or {}
  local out = dense_positions(order_list, index, parent_id)
  cache[parent_id] = out
  return out
end

--- Walk from `id` up to the board, collecting ids self-first and
--- stopping BEFORE the board itself — the board's own level
--- contributes nothing to a path. Bounded at `MAX_DEPTH` hops and
--- guarded against a parent cycle: either one gives up rather than
--- looping, since a chain this broken has nothing honest left to say
--- about rank.
--- @param index Index Items by id
--- @param id string The item to walk up from
--- @return {string} | nil Ids from `id` to its outcome, self-first;
--- nil when the walk found no board within budget
local function walk_to_outcome(index: Index, id: string): {string} | nil
  local chain: {string} = {}
  local seen: {string: boolean} = {}
  local cur = id
  for _ = 1, item.MAX_DEPTH do
    if seen[cur] then
      return nil
    end
    seen[cur] = true
    local i = index[cur]
    if i == nil then
      return nil
    end
    if item.is_parentless(i) then
      -- `rank_of` special-cases `id` itself being the board before
      -- this ever runs, so reaching one here means an ANCESTOR of
      -- `id` is a second parentless item — a broken board, not a path
      -- this walk can honestly complete.
      return nil
    end
    chain[#chain + 1] = cur
    local parent = index[i.parent]
    if parent == nil then
      return nil
    end
    if item.is_parentless(parent) then
      -- `cur` is the outcome: its own parent is the board, so the
      -- walk stops here without adding the board's own level.
      return chain
    end
    cur = i.parent
  end
  return nil
end

--- One item's `Rank`: the board itself gets an empty chain (`is_ranked`
--- reads that as trivially ranked); everything else gets the chain
--- from its outcome down to itself, each level's position drawn from
--- the level above's own list (the board's `order`, at the top) — the
--- outcome level's own position (`chain[1]`) is what `is_ranked` reads
--- as "not triage". A broken or too-deep parent chain has no outcome
--- to walk to, so it comes back with a one-entry chain — itself,
--- unpositioned — which keeps every comparison total without
--- asserting a lineage the data does not honestly have.
--- @param index Index Items by id
--- @param cache PosCache Memo, filled in place
--- @param id string The item's id
--- @return Rank
local function rank_of(index: Index, cache: PosCache, id: string): Rank
  local self = index[id]
  if self ~= nil and item.is_parentless(self) then
    return {chain = {}}
  end
  local up = walk_to_outcome(index, id)
  if up == nil then
    return {chain = {{id = id, position = -1}}}
  end
  local n = #up
  local outcome_id = up[n]
  local outcome = index[outcome_id]
  local board_id = (outcome ~= nil) and outcome.parent or ""
  local chain: {Level} = {}
  for level = 1, n do
    local aid = up[n - level + 1]
    local parent_id = board_id
    if level > 1 then
      parent_id = up[n - level + 2]
    end
    local posmap = positions_for(parent_id, index, cache)
    chain[level] = {id = aid, position = posmap[aid] or -1}
  end
  return {chain = chain}
end

--- Every item's `Rank`. Every queue the board renders sorts by what
--- this returns, so a derivation added here reaches `sorted` and `key`
--- at once — there is no second ordering path to keep in step.
--- @param items {Item} All items
--- @return {string: Rank} Rank by item id
local function positions(items: {Item}): {string: Rank}
  local index = item.by_id(items)
  local cache: PosCache = {}
  local out: {string: Rank} = {}
  for _, i in ipairs(items) do
    out[i.id] = rank_of(index, cache, i.id)
  end
  return out
end

--- Whether an item's outcome is positioned in the board's own `order`
--- — the whole of what "not triage" means. True for the board itself
--- (an empty chain has no outcome to fail the test); otherwise the
--- outcome level's own position, `chain[1]`, is the only placement
--- test there is.
--- @param ranks {string: Rank} Rank by item id
--- @param id string The item's id
--- @return boolean
local function is_ranked(ranks: {string: Rank}, id: string): boolean
  local r = ranks[id]
  if r == nil then
    return false
  end
  if #r.chain == 0 then
    return true
  end
  return r.chain[1].position >= 0
end

--- FNV-1a over a string, folded to 32 bits: the seeded tie-break below
--- needs a stable, cheap, well-mixed order over ids — never
--- cryptography. Pure arithmetic, so every machine agrees.
--- @param text string The text to hash
--- @return integer The 32-bit hash
local function fnv32(text: string): integer
  local h = 2166136261
  for k = 1, #text do
    h = ((h ~ text:byte(k)) * 16777619) & 0xFFFFFFFF
  end
  return h
end

--- Whether `x` sorts before `y`: walk both chains from the outcome level
--- down to the first level naming different ancestors, and decide there.
--- A positioned ancestor sorts before an unpositioned one; two
--- positioned ones sort by position (unique within one parent's list,
--- since both diverge from a shared parent at this level); two
--- unpositioned ones fall back to the seeded hash, or id order with no
--- seed. When one chain is a strict prefix of the other — one item is
--- an ancestor of the other — the shorter one sorts first.
--- @param x Item One item
--- @param y Item The other
--- @param ranks {string: Rank} Rank by item id
--- @param seed string Session tie-break seed, "" for none
--- @return boolean True when x sorts before y
local function less(x: Item, y: Item, ranks: {string: Rank}, seed: string):
  boolean
  local rx = ranks[x.id]
  local ry = ranks[y.id]
  if rx == nil or ry == nil then
    return x.id < y.id
  end
  local cx = rx.chain
  local cy = ry.chain
  local n = #cx
  if #cy < n then
    n = #cy
  end
  for level = 1, n do
    local lx = cx[level]
    local ly = cy[level]
    if lx.id ~= ly.id then
      if lx.position >= 0 and ly.position < 0 then
        return true
      end
      if lx.position < 0 and ly.position >= 0 then
        return false
      end
      if lx.position >= 0 and ly.position >= 0 then
        return lx.position < ly.position
      end
      if seed ~= "" then
        local hx = fnv32(seed .. lx.id)
        local hy = fnv32(seed .. ly.id)
        if hx ~= hy then
          return hx < hy
        end
      end
      return lx.id < ly.id
    end
  end
  if #cx ~= #cy then
    return #cx < #cy
  end
  return x.id < y.id
end

--- A new copy of `list` in rank order: the board first, then each
--- outcome in the board's own order, then down each path the same way,
--- ties among unranked siblings resolving to a seeded fan-out or age.
--- No seed keeps the age tie-break, so reads without one stay stable.
--- @param list {Item} The items to order
--- @param ranks {string: Rank} Rank by item id
--- @param seed string? Per-session tie-break seed; nil or "" for age
--- @return {Item} A sorted copy
local function sorted(list: {Item}, ranks: {string: Rank}, seed?: string):
  {Item}
  local out: {Item} = {}
  for _, i in ipairs(list) do
    out[#out + 1] = i
  end
  local sd = seed or ""
  table.sort(out, function(x: Item, y: Item): boolean
      return less(x, y, ranks, sd)
    end)
  return out
end

--- The zero-padded width of a `key` field's position digits, and the
--- length of a KSUID — the same width an unpositioned field's id
--- fills, so every field is exactly `1 + FIELD_WIDTH` bytes regardless
--- of which form it takes.
local FIELD_WIDTH < const > = 27

--- A sortable text key for one item, matching `sorted(list, ranks)`
--- with no seed (age order among unpositioned ties). The board's own
--- key is "" — empty, a prefix of every other key, so it sorts first.
--- Otherwise one field per chain level, joined by "/": a positioned
--- level renders `"0"` plus its position zero-padded to `FIELD_WIDTH`
--- digits; an unpositioned level renders `"1"` plus the ancestor's own
--- id (already `FIELD_WIDTH` characters), so it sorts after every
--- position at that level and then by id ascending — the same
--- fallback `less` uses with no seed. Every field is the same byte
--- width, so a shorter path (fewer levels) is a byte-for-byte PREFIX
--- of a longer path sharing its ancestors, and sorts first exactly as
--- an ancestor must sort before its descendant. The derived SQLite
--- index's rank-path column mirrors this shape exactly; changing it
--- here means changing that index's column too.
--- @param ranks {string: Rank} Rank by item id
--- @param id string The item's id
--- @return string The sortable key
local function key(ranks: {string: Rank}, id: string): string
  local r = ranks[id]
  if r == nil then
    return "1" .. ("0"):rep(FIELD_WIDTH)
  end
  if #r.chain == 0 then
    -- The board: an empty key, a prefix of every other key, so it
    -- sorts first exactly as `sorted`'s own prefix rule already
    -- treats an ancestor's shorter chain.
    return ""
  end
  local fields: {string} = {}
  for _, level in ipairs(r.chain) do
    if level.position >= 0 then
      fields[#fields + 1] = "0"
      .. ("%0" .. tostring(FIELD_WIDTH) .. "d"):format(level.position)
    else
      fields[#fields + 1] = "1" .. level.id
    end
  end
  return table.concat(fields, "/")
end

local record rank
  type Item = Item
  type Level = Level
  type Rank = Rank
  positions: function(items: {Item}): {string: Rank}
  is_ranked: function(ranks: {string: Rank}, id: string): boolean
  sorted: function(list: {Item}, ranks: {string: Rank},
  seed?: string): {Item}
  key: function(ranks: {string: Rank}, id: string): string
end

local M: rank = {
  positions = positions,
  is_ranked = is_ranked,
  sorted = sorted,
  key = key,
}

return M
