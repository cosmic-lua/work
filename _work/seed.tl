--- The seeded per-session tie-break: a pure hash, and `_work.action`'s
--- own use of it to reorder `_work.read.queue`'s tied rows — split out
--- of `action.tl` to keep that module under the repo's line cap.
---
--- `fnv32` is FNV-1a over a string, folded to 32 bits. Concurrent
--- sessions asking the same board fan out across a tie no judgment
--- separates (two rows a queue's own order leaves equal) instead of
--- converging on the same one — each session's own name seeds a
--- different, stable order over the tied rows. Pure arithmetic, so
--- every machine agrees; never cryptography.
local read = require("_work.read")

local type QueueRow = read.QueueRow

--- Hash a string to a 32-bit integer.
--- @param text string The text to hash
--- @return integer The hash
local function fnv32(text: string): integer
  local h = 2166136261
  for k = 1, #text do
    h = ((h ~ text:byte(k)) * 16777619) & 0xFFFFFFFF
  end
  return h
end

--- The queue key's first UNPOSITIONED field's own end offset — the
--- field width `_work.index_rank`'s `rank_path` view fixes, 28
--- characters ("0" or "1" plus 27 digits/id), "/"-joined. Ties for
--- `tie_break` below are rows sharing an identical key up to and
--- including this field: the point where the view's own order falls
--- back to age (the field's own trailing id) rather than a position.
--- @param key string A `_work.read.QueueRow.key`
--- @return string The prefix; `key` itself when every field is positioned
local function tie_prefix(key: string): string
  local at = 1
  while at <= #key do
    local slash = key:find("/", at, true)
    local stop = (slash or (#key + 1)) - 1
    if key:sub(at, at) == "1" then
      return key:sub(1, stop)
    end
    if slash == nil then
      break
    end
    at = slash + 1
  end
  return key
end

--- `_work.read.queue`'s rows, the seeded tie-break applied: within
--- each run of rows sharing a stage and a `tie_prefix`, reorder by
--- `fnv32(seed .. id)` when `seed` is non-empty; the view's own order
--- (age, by id) stands otherwise. A copy — `rows` is left untouched.
--- @param rows {QueueRow} `_work.read.queue`'s result
--- @param seed string Per-session tie-break seed, "" for age order
--- @return {QueueRow} The reordered copy
local function tie_break(rows: {QueueRow}, seed: string): {QueueRow}
  local out: {QueueRow} = {}
  for _, r in ipairs(rows) do
    out[#out + 1] = r
  end
  if seed == "" then
    return out
  end
  local i = 1
  while i <= #out do
    local group = out[i].stage .. "\0" .. tie_prefix(out[i].key)
    local j = i
    while j < #out and (out[j + 1].stage .. "\0" .. tie_prefix(out[j + 1].key)) == group do
      j = j + 1
    end
    if j > i then
      local slice: {QueueRow} = {}
      for k = i, j do
        slice[#slice + 1] = out[k]
      end
      table.sort(slice, function(a: QueueRow, b: QueueRow): boolean
          return fnv32(seed .. a.id) < fnv32(seed .. b.id)
        end)
      for k = i, j do
        out[k] = slice[k - i + 1]
      end
    end
    i = j + 1
  end
  return out
end

local record seed
  fnv32: function(text: string): integer
  tie_break: function(rows: {QueueRow}, seed: string): {QueueRow}
end

local M: seed = {
  fnv32 = fnv32,
  tie_break = tie_break,
}

return M
