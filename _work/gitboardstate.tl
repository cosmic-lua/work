--- The two board-level refs beside the item namespaces —
--- `refs/heads/board/seq` (a bare lease, no content of its own) and
--- `refs/heads/board/format` (one blob, `format`) — split out of
--- `_work.gitread` to keep that module under its line cap: `list`'s
--- one `for-each-ref` pass mixes these in with the item namespaces,
--- and its one batch session answers their blob queries alongside
--- every item's own. The board's own outcome ranking is no longer a
--- third such ref — it is the board item's own `order` field, read
--- and written exactly like any other item's.
local gitobj = require("_work.gitobj")

--- The two tips, as one `for-each-ref` pass found them; "" for either
--- not present.
local record Refs
  seq_sha: string
  format_sha: string
end

--- Fresh `Refs`, both tips absent.
--- @return Refs
local function refs_new(): Refs
  return {seq_sha = "", format_sha = ""}
end

--- Record one `for-each-ref` entry onto `out` when it names one of the
--- two refs.
--- @param out Refs Accumulator, mutated in place
--- @param refname string The entry's full ref name
--- @param sha string Its tip
--- @return boolean True when this was one of the two — the caller's
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
  return false
end

--- Append the `format` blob query onto the caller's own batch request,
--- when its tip is actually present.
--- @param r Refs The two tips
--- @param out {string} The query list to append onto, mutated in place
local function append_queries(r: Refs, out: {string})
  if r.format_sha ~= "" then
    out[#out + 1] = r.format_sha .. ":format"
  end
end

--- `format`'s raw content, read back from a batch that answered
--- `append_queries(r, ...)`'s entry.
--- @param r Refs The two tips
--- @param batch {string: gitobj.BatchEntry} The batch that answered them
--- @return string The format marker's content, "" when absent
local function read(r: Refs, batch: {string: gitobj.BatchEntry}): string
  if r.format_sha == "" then
    return ""
  end
  local entry = batch[r.format_sha .. ":format"]
  if entry == nil then
    return ""
  end
  return entry.content
end

local record gitboardstate
  type Refs = Refs
  refs_new: function(): Refs
  absorb: function(out: Refs, refname: string, sha: string): boolean
  append_queries: function(r: Refs, out: {string})
  read: function(r: Refs, batch: {string: gitobj.BatchEntry}): string
end

local M: gitboardstate = {
  refs_new = refs_new,
  absorb = absorb,
  append_queries = append_queries,
  read = read,
}

return M
