--- `store.list`, but read past a layout-1 board's format refusal
--- instead of failing on it: `gitboard migrate` is the only caller
--- allowed to see an old-layout board this way (`_work.gitread.list`'s
--- `allow_old_format` parameter is the actual exemption; every other
--- verb still calls `store.list`, which never passes it, so every
--- other read still refuses layout 1 exactly as before). Split out of
--- `_work.store` to keep that file under the line cap — this is
--- `store.list`'s own body, copied rather than shared, since the only
--- difference is the one argument `gitread.list` takes.
local gitread = require("_work.gitread")
local item = require("_work.item")
local store = require("_work.store")

--- Every item in the store, done ones included, sorted by id, leasing
--- and snapshotting each exactly as `store.list` does — `gitboard
--- migrate` is the only caller.
--- @param s store.Store The store
--- @return {item.Item} | nil The items, some possibly flagged
--- @return string Error message naming the first genuinely corrupt item
local function list_for_migrate(s: store.Store): {item.Item} | nil, string
  local board, err = gitread.list(s.root, true)
  if board == nil then
    return nil, err
  end
  for id, ref in pairs(board.refs_by_id) do
    s.leased_ref[id] = ref
    s.leased_sha[id] = board.shas_by_id[id]
  end
  for _, it in ipairs(board.items) do
    s.leased_item[it.id] = store.snapshot_item(it)
  end
  s.observed_seq = board.seq_sha
  s.duplicates = board.duplicates
  s.board_digest = board.refs_digest
  return board.items
end

local record storemigrate
  list_for_migrate: function(s: store.Store): {item.Item} | nil, string
end

local M: storemigrate = {
  list_for_migrate = list_for_migrate,
}

return M
