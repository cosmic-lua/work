--- The `rank` verb: an item's position among its siblings — before,
--- after, or last in the shared parent's `order`, the board's own
--- `order` included, since the board holds its outcomes' list exactly
--- as any other parent holds its children's. `place_under` is the
--- same placement math `_work.gitgraph`'s `attach`/`new` reuse for
--- their own `--before`/`--after`, so a child that already knows where
--- it goes lands parented and positioned in one commit.
local flow = require("_work.flow")
local gate = require("_work.gitgate")
local item = require("_work.item")
local store = require("_work.store")

--- One id's parent, described for a sibling-mismatch refusal: "the
--- board" for "", "under <handle>" otherwise.
--- @param p string A parent id, "" for the board
--- @return string The description
local function parent_desc(p: string): string
  if p == "" then
    return "the board"
  end
  return ("under %s"):format(p:sub(1, 8))
end

--- The refusal naming both parents when ID and X are not siblings.
--- @param it item.Item The item being ranked
--- @param xit item.Item The item it was asked to rank against
--- @return string The refusal
local function sibling_refusal(it: item.Item, xit: item.Item): string
  return ("REFUSED: %s and %s are not siblings — %s is %s, %s is %s"):format(
    it.id:sub(1, 8), xit.id:sub(1, 8), it.id:sub(1, 8), parent_desc(it.parent or ""),
    xit.id:sub(1, 8), parent_desc(xit.parent or ""))
end

--- Where ID lands, for a commit subject and a verdict line alike.
--- @param before string X to place ID before; "" when unused
--- @param after string X to place ID after; "" when unused
--- @param last boolean True when ID goes last regardless of X
--- @param where string "under <parent handle>"
--- @return string The description
local function describe(before: string, after: string, last: boolean,
    where: string): string
  if last then
    return ("last %s"):format(where)
  end
  if before ~= "" then
    return ("before %s %s"):format(before:sub(1, 8), where)
  end
  return ("after %s %s"):format(after:sub(1, 8), where)
end

--- Position ID within an ordered list: remove it if present, then
--- insert immediately before or after X (whichever was given), or
--- append when `last`. X absent from `order` is refused as
--- unpositioned rather than silently appending — a caller who wants
--- ID last says so with `--last`. Every other entry is left exactly
--- as it stood, stale ones included: reads ignore them, and this
--- never prunes on their behalf.
--- @param order {string} Current order, in rank order
--- @param id string The id being placed
--- @param before string X to place ID before; "" when unused
--- @param after string X to place ID after; "" when unused
--- @param last boolean True to place ID last regardless of X
--- @return {string} | nil The new order
--- @return string Error message
local function place(order: {string}, id: string, before: string, after: string,
    last: boolean): {string} | nil, string
  local without: {string} = {}
  for _, v in ipairs(order) do
    if v ~= id then
      without[#without + 1] = v
    end
  end
  if last then
    without[#without + 1] = id
    return without, ""
  end
  local x = before
  if x == "" then
    x = after
  end
  local at: integer = nil
  for i, v in ipairs(without) do
    if v == x then
      at = i
      break
    end
  end
  if at == nil then
    return nil, ("%s is unpositioned among its siblings — rank it first, "
      .. "or use --last"):format(x:sub(1, 8))
  end
  local out: {string} = {}
  for i, v in ipairs(without) do
    if before ~= "" and i == at then
      out[#out + 1] = id
    end
    out[#out + 1] = v
    if after ~= "" and i == at then
      out[#out + 1] = id
    end
  end
  return out, ""
end

--- Place ID into PARENT's `order` relative to X (`--before`/`--after`),
--- for `attach`/`new`'s own placement option: a child that already
--- knows where it goes among its new siblings lands positioned in the
--- same commit that parents it. Call only when at least one of
--- `before`/`after` is given — a caller with neither has nothing to
--- place, and skips this entirely; the item stays unranked among its
--- new siblings exactly as it always was.
--- @param parent_item item.Item The new parent, already resolved
--- @param id string The item being placed under it
--- @param before string X to place ID before; "" when unused
--- @param after string X to place ID after; "" when unused, but not
--- both "" — the caller's job to check
--- @param index flow.Index Every item by id, to check X's own parent
--- @return boolean True on success; `parent_item.order` was mutated
--- @return string Refusal reason; "" only on success
local function place_under(parent_item: item.Item, id: string, before: string,
    after: string, index: flow.Index): boolean, string
  if before ~= "" and after ~= "" then
    return false, "REFUSED: at most one of --before/--after may be given"
  end
  local x = before
  if x == "" then
    x = after
  end
  if x == id then
    return false, "an item cannot rank against itself"
  end
  local xit = index[x]
  if xit == nil then
    return false, ("no item %s"):format(x)
  end
  if (xit.parent or "") ~= parent_item.id then
    return false, ("REFUSED: %s is not a child of %s"):format(
      x:sub(1, 8), parent_item.id:sub(1, 8))
  end
  local new_order, perr = place(parent_item.order or {}, id, before, after, false)
  if new_order == nil then
    return false, "REFUSED: " .. perr
  end
  parent_item.order = new_order
  return true, ""
end

--- rank: position ID among its siblings — before X, after X, or last —
--- same-parent items against each other, an outcome against other
--- outcomes the same way (the board is simply its parent, holding its
--- outcomes' `order` exactly as any parent holds its children's). The
--- parent's `order` is the one blob this writes; it never touches
--- `refs/heads/board/seq` — the parent's own ref is the lease. Refused
--- on the board itself: it has no siblings to rank among.
--- @param s store.Store The store
--- @param id string The item to position
--- @param before string X to place ID before; "" when unused
--- @param after string X to place ID after; "" when unused
--- @param last boolean True to place ID last among its siblings
--- @return integer 0 on success, 1 otherwise
local function cmd_rank(s: store.Store, id: string, before: string, after: string,
    last: boolean): integer
  local count = 0
  if before ~= "" then count = count + 1 end
  if after ~= "" then count = count + 1 end
  if last then count = count + 1 end
  if count ~= 1 then
    return gate.verdict_line("rank", false,
      "REFUSED: rank needs exactly one of --before X, --after X, --last")
  end
  local all, aerr = store.list(s)
  if all == nil then
    return gate.verdict_line("rank", false, aerr)
  end
  local index = flow.by_id(all)
  local it = index[id]
  if it == nil then
    return gate.verdict_line("rank", false, ("no item %s"):format(id))
  end
  if not item.is_open(it) then
    return gate.verdict_line("rank", false,
      ("REFUSED: %s is done (%s) — a finished item's position is history, "
        .. "not a repair target"):format(id:sub(1, 8), it.resolution))
  end
  local parent_id = it.parent or ""
  if parent_id == "" then
    return gate.verdict_line("rank", false,
      "REFUSED: the board has no siblings to rank among")
  end
  local x = before
  if x == "" then
    x = after
  end
  if x ~= "" then
    if x == id then
      return gate.verdict_line("rank", false, "an item cannot rank against itself")
    end
    local xit = index[x]
    if xit == nil then
      return gate.verdict_line("rank", false, ("no item %s"):format(x))
    end
    if (it.parent or "") ~= (xit.parent or "") then
      return gate.verdict_line("rank", false, sibling_refusal(it, xit))
    end
  end
  local parent_item = index[parent_id]
  if parent_item == nil then
    return gate.verdict_line("rank", false,
      ("%s's parent is broken: no item %s"):format(id:sub(1, 8), parent_id))
  end
  local new_order, perr = place(parent_item.order or {}, id, before, after, last)
  if new_order == nil then
    return gate.verdict_line("rank", false, "REFUSED: " .. perr)
  end
  parent_item.order = new_order
  local where = ("under %s"):format(parent_id:sub(1, 8))
  local ok, err = gate.commit_and_publish(s, parent_item, nil,
    ("rank %s %s"):format(id:sub(1, 8), describe(before, after, last, where)), "rank")
  if not ok then
    return gate.verdict_line("rank", false, err)
  end
  if store.is_noop(err) then
    return gate.verdict_line("rank", true, err)
  end
  return gate.verdict_line("rank", true,
    ("%s now ranks %s"):format(id:sub(1, 8), describe(before, after, last, where)))
end

local record gitrank
  place_under: function(parent_item: item.Item, id: string, before: string,
  after: string, index: flow.Index): boolean, string
  cmd_rank: function(s: store.Store, id: string, before: string, after: string,
  last: boolean): integer
end

local M: gitrank = {
  place_under = place_under,
  cmd_rank = cmd_rank,
}

return M
