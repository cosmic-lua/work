--- Native board read facade. Format-5 parsing is migration-only.
local boardread = require("_work.boardread")
local boardhistory = require("_work.boardhistory")
local format = require("_work.format")
local gitbatch = require("_work.gitbatch")
local item = require("_work.item")
local refs = require("_work.refs")
local record Loaded
  it: item.Item
  ref: string
  sha: string
end

--- One native snapshot, with its path-attributed history and cache digest.
local record Board
  native_view: boardread.View
  native_history: boardhistory.History
  items: {item.Item}
  refs_by_id: {string: string}
  shas_by_id: {string: string}
  touched_by_id: {string: integer}
  refs_digest: string
end

local function list(root: string, snapshot?: {refs.RefEntry}, _reader?: gitbatch.BatchSession): Board | nil, string
  local head, err = format.state_head(root, snapshot)
  if head == nil then return nil, err end
  local view, verr = boardread.list(root, head)
  if view == nil then return nil, verr end
  local history, herr = boardhistory.read(root, head)
  if history == nil then return nil, herr end
  local native_refs: {string: string} = {}
  for _, it in ipairs(view.items) do native_refs[it.id] = "refs/heads/state" end
  return {native_view = view, native_history = history, items = view.items, refs_by_id = native_refs,
    shas_by_id = history.tip_by_id, touched_by_id = history.touched_by_id,
    refs_digest = head}, ""
end
local function load_item(root: string, id: string): Loaded | nil, string
  local board, err = list(root)
  if board == nil then return nil, err end
  for _, it in ipairs(board.items) do
    if it.id == id then return {it = it, ref = "refs/heads/state", sha = board.shas_by_id[id]}, "" end
  end
  return nil, "no item " .. id
end
local record Module
  type Board = Board
  type Loaded = Loaded
  list: function(root: string, snapshot?: {refs.RefEntry}, reader?: gitbatch.BatchSession): Board | nil, string
  load: function(root: string, id: string): Loaded | nil, string
end
local M: Module = {list = list, load = load_item}
return M
