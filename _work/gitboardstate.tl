--- The three board-level refs beside the item namespaces —
--- `refs/heads/board/seq` (a bare lease, no content of its own),
--- `refs/heads/board/format` (one blob, `format`), and
--- `refs/heads/board/order` (one blob, `order`, the board's own root
--- ranking — the same shape an item's own `order` blob carries) —
--- split out of `_work.gitread` to keep that module under its line
--- cap: `list`'s one `for-each-ref` pass mixes these in with the item
--- namespaces, and its one batch session answers their blob queries
--- alongside every item's own.
local gitobj = require("_work.gitobj")
local itemtree = require("_work.itemtree")

--- The three tips, as one `for-each-ref` pass found them; "" for any
--- not present.
local record Refs
  seq_sha: string
  format_sha: string
  order_sha: string
end

--- Fresh `Refs`, every tip absent.
--- @return Refs
local function refs_new(): Refs
  return {seq_sha = "", format_sha = "", order_sha = ""}
end

--- Record one `for-each-ref` entry onto `out` when it names one of the
--- three refs.
--- @param out Refs Accumulator, mutated in place
--- @param refname string The entry's full ref name
--- @param sha string Its tip
--- @return boolean True when this was one of the three — the caller's
--- own per-item handling skips it
local function absorb(out: Refs, refname: string, sha: string): boolean
  if refname == "refs/heads/board/seq" then
    out.seq_sha = sha
    return true
  end
  if refname == "refs/heads/board/format" then
    out.format_sha = sha
    return true
  end
  if refname == "refs/heads/board/order" then
    out.order_sha = sha
    return true
  end
  return false
end

--- Append the `format`/`order` blob queries onto the caller's own
--- batch request, one per tip actually present.
--- @param r Refs The three tips
--- @param out {string} The query list to append onto, mutated in place
local function append_queries(r: Refs, out: {string})
  if r.format_sha ~= "" then
    out[#out + 1] = r.format_sha .. ":format"
  end
  if r.order_sha ~= "" then
    out[#out + 1] = r.order_sha .. ":order"
  end
end

--- `format`'s raw content, and `order`'s already-parsed root ranking,
--- read back from a batch that answered `append_queries(r, ...)`'s entries.
--- @param r Refs The three tips
--- @param batch {string: gitobj.BatchEntry} The batch that answered them
--- @return string The format marker's content, "" when absent
--- @return {string} The board's root ranking, possibly empty
local function read(r: Refs, batch: {string: gitobj.BatchEntry}): string, {string}
  local format_content = ""
  if r.format_sha ~= "" then
    local entry = batch[r.format_sha .. ":format"]
    if entry ~= nil then
      format_content = entry.content
    end
  end
  local root_order: {string} = {}
  if r.order_sha ~= "" then
    local entry = batch[r.order_sha .. ":order"]
    if entry ~= nil then
      root_order = itemtree.parse_order(entry.content)
    end
  end
  return format_content, root_order
end

local record gitboardstate
  type Refs = Refs
  refs_new: function(): Refs
  absorb: function(out: Refs, refname: string, sha: string): boolean
  append_queries: function(r: Refs, out: {string})
  read: function(r: Refs, batch: {string: gitobj.BatchEntry}): string, {string}
end

local M: gitboardstate = {
  refs_new = refs_new,
  absorb = absorb,
  append_queries = append_queries,
  read = read,
}

return M
