--- Item shaping the store hands out, needing no open repository: an
--- independent copy of an item as OBSERVED, and the one-line summary of the
--- ones a read flagged. Split out of `_work.store` to keep that module under
--- the line cap; it holds nothing but these two pure functions over
--- `_work.item`, which is why neither takes a `Store` and why `_work.store`
--- can re-export both without a dependency back.
local item = require("_work.item")

--- An independent copy of `it`, sharing no table with it — `encode` then
--- `decode` round-trips through fresh tables at every level (`_work.item`'s own
--- tested inverse pair), which is cheaper to lean on than a bespoke deep copy.
--- Used to snapshot an item as OBSERVED, before any caller mutates the object
--- `load`/`list` handed back: `decode`'s own tolerance means this can only fail
--- on an item already flagged unreadable, and a missing snapshot costs the
--- fast-import diff (`_work.fastimport.diff_item`) only writing every path for
--- that one item unconditionally, never a wrong answer.
---
--- `other_edges` is deep-copied by hand: it is carried opaquely by
--- `_work.itemtree` (the ref layout), never by `item.encode`/`decode` (the
--- older literal-table codec), so the round trip would otherwise drop it
--- silently — invisible for an ordinary item, which has none, and exactly the
--- field a diff over an unmigrated board's edges needs an honest baseline for.
--- @param it item.Item The item to copy
--- @return item.Item | nil The copy, nil when re-decoding it failed
local function snapshot(it: item.Item): item.Item | nil
  local copy, _err = item.decode(item.encode(it))
  if copy == nil then
    return nil
  end
  -- Claim fields are derived from the native claim blob, outside item.encode.
  copy.claim, copy.claim_base, copy.claim_batch = it.claim, it.claim_base, it.claim_batch
  local other_edges = it.other_edges
  if other_edges ~= nil then
    local edges_copy: {string: {string: string}} = {}
    for kind, idmap in pairs(other_edges) do
      local inner: {string: string} = {}
      for id, content in pairs(idmap) do
        inner[id] = content
      end
      edges_copy[kind] = inner
    end
    copy.other_edges = edges_copy
  end
  return copy
end

--- One line summarizing every item a read flagged, in list order; "" when
--- nothing was.
--- @param items {item.Item} Items from `store.list`
--- @return string "N unreadable/flagged: <id8> — <reason>[; ...]", or ""
local function flagged_summary(items: {item.Item}): string
  local parts: {string} = {}
  for _, it in ipairs(items) do
    if item.is_flagged(it) then
      parts[#parts + 1] = ("%s — %s"):format(it.id:sub(1, 8),
        table.concat(it.decode_problems or {}, ", "))
    end
  end
  if #parts == 0 then
    return ""
  end
  return ("%d unreadable/flagged: %s"):format(#parts, table.concat(parts, "; "))
end

local record storeitem
  snapshot: function(it: item.Item): item.Item | nil
  flagged_summary: function(items: {item.Item}): string
end

local M: storeitem = {snapshot = snapshot, flagged_summary = flagged_summary}

return M
