--- Per-item facts read off one `for-each-ref` snapshot over the board
--- cache's watched patterns (`_work.cachedb.WATCH_PATTERNS`), keyed by
--- item id rather than refname — split out of `_work.cachedb` to keep
--- that module under the repo's line cap. `_work.cache`'s fetch path
--- (`around_fetch`) already takes such a snapshot before and after the
--- fetch to compute the changed-id set; this module is what lets it
--- read a patched item's new committer date and the board's own
--- `refs/heads/board/seq` tip from that SAME snapshot, with no further
--- git read.
local refs = require("_work.refs")

--- Every watched ref's committer date, keyed by item id — the same
--- two-pass, `ended/`-wins-on-duplicate rule
--- `_work.cachedb.shas_by_item` uses (`refs/heads/board/*` entries
--- carry no id and are dropped): a legacy id can still be filed under
--- BOTH `refs/heads/items/<id>` and `refs/heads/ended/<id>` at once,
--- and the second pass's overwrite makes `ended/` the deterministic
--- winner regardless of `for-each-ref`'s own listing order.
--- @param entries {refs.RefEntry} A ref listing
--- @return {string: integer} Item id -> committer date, epoch seconds
local function touched_by_item(entries: {refs.RefEntry}): {string: integer}
  local out: {string: integer} = {}
  for _, e in ipairs(entries) do
    local id = e.refname:match("^refs/heads/items/(.+)$")
    if id then
      out[id] = e.touched
    end
  end
  for _, e in ipairs(entries) do
    local id = e.refname:match("^refs/heads/ended/(.+)$")
    if id then
      out[id] = e.touched
    end
  end
  return out
end

--- `refs/heads/board/seq`'s own tip from a ref listing, "" when the
--- listing carries no such entry (a board that has never minted a
--- short key yet).
--- @param entries {refs.RefEntry} A ref listing
--- @return string The tip sha, possibly ""
local function seq_sha_of(entries: {refs.RefEntry}): string
  for _, e in ipairs(entries) do
    if e.refname == "refs/heads/board/seq" then
      return e.sha
    end
  end
  return ""
end

local record cachewatch
  touched_by_item: function(entries: {refs.RefEntry}): {string: integer}
  seq_sha_of: function(entries: {refs.RefEntry}): string
end

local M: cachewatch = {
  touched_by_item = touched_by_item,
  seq_sha_of = seq_sha_of,
}

return M
