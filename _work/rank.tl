--- An item's rank is a path: its root's rank among roots, then its
--- rank among its siblings at each level down. Rank among siblings is
--- a position in a list the parent holds; siblings not in the list
--- follow it, by age. A root not in the board's list, and everything
--- under it, is triage.
---
--- This module derives that path for every item and compares two
--- paths against each other; it holds no store and no git, and reads
--- nothing but the item list and the board's root list handed to it.
--- Walking down from the root: at each level, an ancestor's position
--- is looked up in the id list its OWN parent holds (`Item.order`, or
--- `root_order` for a root) — dense over entries that actually name a
--- current child of that parent, so an id left behind by a move (no
--- longer a real child) is skipped rather than consuming a slot, and
--- two identical entries consume only one. An id absent from its
--- parent's list is unranked among its siblings: it still gets a
--- level in the path, just with no position at that level.
---
--- Comparing two items walks both paths from the root down to the
--- first level where they name different ancestors. There, a
--- positioned ancestor sorts before an unpositioned one; two
--- positioned ancestors sort by position; two unpositioned ones fall
--- back to age (id order — KSUIDs sort by creation time) or, when a
--- session seed is given, a hash of the seed and the ancestor's id, so
--- concurrent sessions fan out across ties instead of converging on
--- the same one. When one path is a strict prefix of the other, the
--- shorter one — the ancestor — sorts first.
---
--- Pure functions over a list of items plus the root list: no store,
--- no network. The module deliberately requires only `_work.item`, so
--- `_work.flow` may build on it without a cycle.
local item = require("_work.item")

local type Item = item.Item

--- Items indexed by id.
local type Index = {string: Item}

--- The most parent hops a walk to the root takes before giving up —
--- matches `_work.priority` and `_work.flow`'s own trace bound: deeper
--- nesting than this is its own design smell, and a chain this long is
--- cyclic in practice.
local MAX_DEPTH < const > = 16

--- One ancestor's position in ITS OWN parent's list — one entry of a
--- `Rank.chain`.
local record Level
  --- The ancestor's id.
  id: string
  --- Its dense position among its parent's real, listed children;
  --- -1 when it names no entry in that list (unranked at this level).
  position: integer
end

--- One item's rank: the root-down path a comparison walks.
local record Rank
  --- Whether this item's ROOT appears in the board's root list — the
  --- only placement test there is. False for a root itself absent
  --- from the list, and for everything under it: `_work/priority.tl`'s
  --- `Position.placed`, restated for a position instead of a
  --- comparison.
  ranked: boolean
  --- The ancestor chain from the root down to this item, inclusive —
  --- always at least one entry (the item itself), even when the walk
  --- to the root failed (see `positions`).
  chain: {Level}
end

--- Positions by parent id, memoized: "" is the board's own root list,
--- any other key is that item's own `order`. Every sibling under one
--- parent shares the same dense map, so this is built once per parent
--- no matter how many of its descendants are ranked.
local type PosMap = {string: integer}
local type PosCache = {string: PosMap}

--- Items indexed by id.
--- @param items {Item} All items
--- @return Index The index
local function index_of(items: {Item}): Index
  local out: Index = {}
  for _, i in ipairs(items) do
    out[i.id] = i
  end
  return out
end

--- Whether `id` is a CURRENT real child of `parent_id`: it exists and
--- its own `parent` field still names `parent_id`. A stale list entry
--- — left over after a move — names a real item that no longer
--- qualifies, and is skipped rather than error, exactly like a
--- dangling `beats`/`blocked_by` id elsewhere in this tree.
--- @param index Index Items by id
--- @param parent_id string The parent's id, "" for the board's roots
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
--- @param parent_id string The parent's id, "" for the board's roots
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

--- `dense_positions` for one parent, memoized in `cache`.
--- @param parent_id string The parent's id, "" for the board's roots
--- @param index Index Items by id
--- @param root_order {string} The board's root list
--- @param cache PosCache Memo, filled in place
--- @return PosMap Dense position by child id
local function positions_for(parent_id: string, index: Index,
    root_order: {string}, cache: PosCache): PosMap
  local cached = cache[parent_id]
  if cached ~= nil then
    return cached
  end
  local order_list: {string} = root_order
  if parent_id ~= "" then
    local parent = index[parent_id]
    order_list = (parent ~= nil and parent.order) or {}
  end
  local out = dense_positions(order_list, index, parent_id)
  cache[parent_id] = out
  return out
end

--- Walk from `id` up to its root, collecting ids self-first. Bounded
--- at `MAX_DEPTH` hops and guarded against a parent cycle: either one
--- gives up rather than looping, since a chain this broken has nothing
--- honest left to say about rank.
--- @param index Index Items by id
--- @param id string The item to walk up from
--- @return {string} | nil Ids from `id` to its root, self-first; nil
--- when the walk found no root within budget
local function walk_to_root(index: Index, id: string): {string} | nil
  local chain: {string} = {}
  local seen: {string: boolean} = {}
  local cur = id
  for _ = 1, MAX_DEPTH do
    if seen[cur] then
      return nil
    end
    seen[cur] = true
    local it = index[cur]
    if it == nil then
      return nil
    end
    chain[#chain + 1] = cur
    if (it.parent or "") == "" then
      return chain
    end
    cur = it.parent
  end
  return nil
end

--- One item's `Rank`: `ranked` from its root's membership in
--- `root_order`, and the chain from that root down to itself, each
--- level's position drawn from the level above's own list (the
--- board's root list, at the top). A broken or too-deep parent chain
--- has no root to test membership of and no path to walk, so it comes
--- back unranked with a one-entry chain — itself, unpositioned — which
--- keeps every comparison total without asserting a lineage the data
--- does not honestly have.
--- @param index Index Items by id
--- @param root_order {string} The board's root list
--- @param cache PosCache Memo, filled in place
--- @param id string The item's id
--- @return Rank
local function rank_of(index: Index, root_order: {string}, cache: PosCache,
    id: string): Rank
  local up = walk_to_root(index, id)
  if up == nil then
    return {ranked = false, chain = {{id = id, position = -1}}}
  end
  local n = #up
  local root_id = up[n]
  local ranked = false
  for _, rid in ipairs(root_order) do
    if rid == root_id then
      ranked = true
      break
    end
  end
  local chain: {Level} = {}
  for level = 1, n do
    local aid = up[n - level + 1]
    local parent_id = ""
    if level > 1 then
      parent_id = up[n - level + 2]
    end
    local posmap = positions_for(parent_id, index, root_order, cache)
    chain[level] = {id = aid, position = posmap[aid] or -1}
  end
  return {ranked = ranked, chain = chain}
end

--- Every item's `Rank`. Every queue the board renders sorts by what
--- this returns, so a derivation added here reaches `sorted`, `key`
--- and `describe` at once — there is no second ordering path to keep
--- in step.
--- @param items {Item} All items
--- @param root_order {string} The board's root list
--- @return {string: Rank} Rank by item id
local function positions(items: {Item}, root_order: {string}): {string: Rank}
  local index = index_of(items)
  local cache: PosCache = {}
  local out: {string: Rank} = {}
  for _, it in ipairs(items) do
    out[it.id] = rank_of(index, root_order, cache, it.id)
  end
  return out
end

--- Whether an item's root is in the board's list — the whole of what
--- "not triage" means.
--- @param ranks {string: Rank} Rank by item id
--- @param id string The item's id
--- @return boolean
local function is_ranked(ranks: {string: Rank}, id: string): boolean
  local r = ranks[id]
  return r ~= nil and r.ranked
end

--- FNV-1a over a string, folded to 32 bits: the seeded tie-break below
--- needs a stable, cheap, well-mixed order over ids — never
--- cryptography. Pure arithmetic, so every machine agrees. Copied from
--- `_work.priority`, which needs the identical shape for its own
--- seeded tie-break.
--- @param text string The text to hash
--- @return integer The 32-bit hash
local function fnv32(text: string): integer
  local h = 2166136261
  for k = 1, #text do
    h = ((h ~ text:byte(k)) * 16777619) & 0xFFFFFFFF
  end
  return h
end

--- Whether `x` sorts before `y`: walk both chains from the root down
--- to the first level naming different ancestors, and decide there. A
--- positioned ancestor sorts before an unpositioned one; two
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

--- A new copy of `list` in rank order: root first among roots, then
--- down each path the same way, ties among unranked siblings
--- resolving to a seeded fan-out or age. No seed keeps the age
--- tie-break, so reads without a session stay stable.
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
--- with no seed (age order among unpositioned ties). One field per
--- chain level, joined by "/": a positioned level renders `"0"` plus
--- its position zero-padded to `FIELD_WIDTH` digits; an unpositioned
--- level renders `"1"` plus the ancestor's own id (already
--- `FIELD_WIDTH` characters), so it sorts after every position at that
--- level and then by id ascending — the same fallback `less` uses with
--- no seed. Every field is the same byte width, so a shorter path
--- (fewer levels) is a byte-for-byte PREFIX of a longer path sharing
--- its ancestors, and sorts first exactly as an ancestor must sort
--- before its descendant. The derived SQLite index's rank-path column
--- mirrors this shape exactly; changing it here means changing that
--- index's column too.
--- @param ranks {string: Rank} Rank by item id
--- @param id string The item's id
--- @return string The sortable key
local function key(ranks: {string: Rank}, id: string): string
  local r = ranks[id]
  if r == nil or #r.chain == 0 then
    return "1" .. ("0"):rep(FIELD_WIDTH)
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

--- The item named `id` in `items`, or nil.
--- @param items {Item} All items
--- @param id string The id to find
--- @return Item | nil
local function find_item(items: {Item}, id: string): Item | nil
  for _, i in ipairs(items) do
    if i.id == id then
      return i
    end
  end
  return nil
end

--- Mirrors `_work.tail.handle`'s 8-character convention (guillemet-
--- wrapped, underscore-divided tail) without requiring that module —
--- this one requires only `_work.item`, so a later `describe` caller
--- (`show`) sees the same rendering either way.
--- @param id string A full item id (a 27-char KSUID)
--- @return string "«XXXX_XXXX»"
local function handle_of(id: string): string
  local t = id:sub(20)
  return "«" .. t:sub(1, 4) .. "_" .. t:sub(5, 8) .. "»"
end

--- The render `show` uses for one item's rank: "3 of 7 under «HANDLE»"
--- for a parented item (7 = how many of its siblings are positioned),
--- "root 2 of 5" for a root, or "unranked" when the item's own parent
--- has no position for it (roots included — the board is a root's
--- "parent" for this purpose).
--- @param ranks {string: Rank} Rank by item id
--- @param items {Item} All items
--- @param id string The item's id
--- @return string
local function describe(ranks: {string: Rank}, items: {Item}, id: string):
  string
  local r = ranks[id]
  local it = find_item(items, id)
  if r == nil or it == nil or #r.chain == 0 then
    return "unranked"
  end
  local own = r.chain[#r.chain]
  if own.position < 0 then
    return "unranked"
  end
  local parent_id = it.parent or ""
  local total = 0
  for _, other in ipairs(items) do
    if (other.parent or "") == parent_id then
      local orank = ranks[other.id]
      if orank ~= nil and #orank.chain > 0
      and orank.chain[#orank.chain].position >= 0 then
        total = total + 1
      end
    end
  end
  if parent_id == "" then
    return ("root %d of %d"):format(own.position + 1, total)
  end
  return ("%d of %d under %s"):format(own.position + 1, total,
    handle_of(parent_id))
end

local record rank
  type Item = Item
  type Level = Level
  type Rank = Rank
  positions: function(items: {Item}, root_order: {string}): {string: Rank}
  is_ranked: function(ranks: {string: Rank}, id: string): boolean
  sorted: function(list: {Item}, ranks: {string: Rank},
  seed?: string): {Item}
  key: function(ranks: {string: Rank}, id: string): string
  describe: function(ranks: {string: Rank}, items: {Item}, id: string): string
end

local M: rank = {
  positions = positions,
  is_ranked = is_ranked,
  sorted = sorted,
  key = key,
  describe = describe,
}

return M
