--- One invocation's initial canonical snapshot and scoped Git batch reader.
--- The marker read and the first item read share the existing gitbatch process.
local cachedb = require("_work.cachedb")
local format = require("_work.format")
local gitread = require("_work.gitread")
local gitbatch = require("_work.gitbatch")
local refs = require("_work.refs")
local record Start
  snapshot: {refs.RefEntry}
  reader: gitbatch.BatchSession | nil
  head: string
end

local function close(start: Start | nil): boolean, string
  if start == nil then return true, "" end
  local reader = start.reader
  start.reader = nil
  if reader ~= nil then return reader:close() end
  return true, ""
end

local function open(root: string): Start | nil, string
  local snapshot, err = refs.for_each_ref(root, cachedb.WATCH_PATTERNS)
  if snapshot == nil then return nil, err end
  local out: Start = {snapshot = snapshot, head = "", reader = nil}
  local sha = ""
  for _, entry in ipairs(snapshot) do
    if entry.refname == "refs/heads/board/format" then sha = entry.sha end
  end
  if sha ~= "" and format.known_content(sha) == nil then
    local content: string
    do
      local reader, rerr = gitbatch.batch_session(root)
      if reader == nil then return nil, rerr end
      out.reader = reader
      local batch, berr = reader:request({sha .. ":format"})
      if batch == nil then local _ok, _err = close(out); return nil, berr end
      local marker = batch[sha .. ":format"]
      if marker == nil or marker.otype ~= "blob" then
        local _ok, _err = close(out)
        return nil, "format marker is unreadable"
      end
      content = marker.content
    end
    format.remember(sha, content)
  end
  local head, herr = format.state_head(root, snapshot)
  if head == nil then local _ok, _err = close(out); return nil, herr end
  out.head = head
  if head ~= "" then
    out.snapshot[#out.snapshot + 1] = {refname = "refs/heads/state", sha = head, touched = 0}
    local closed, cerr = close(out)
    if not closed then return nil, cerr end
  end
  return out, ""
end

--- Resolve an item within the captured snapshot, including legacy duplicates.
local function lease(root: string, start: Start, id: string): string, string
  local matching: {refs.RefEntry} = {}
  for _, entry in ipairs(start.snapshot) do
    if entry.refname == "refs/heads/items/" .. id or entry.refname == "refs/heads/ended/" .. id then
      matching[#matching + 1] = entry
    end
  end
  if #matching == 0 then return "", "" end
  local chosen = matching[1]
  if #matching == 2 then
    local items, ended = matching[1], matching[2]
    if items.refname ~= "refs/heads/items/" .. id then items, ended = ended, items end
    chosen = gitread.pick_duplicate(root, items, ended)
  end
  return chosen.refname, chosen.sha
end

local record stateread_start
  type Start = Start
  lease: function(root: string, start: Start, id: string): string, string
  open: function(root: string): Start | nil, string
  close: function(start: Start | nil): boolean, string
end
local M: stateread_start = {open = open, close = close, lease = lease}
return M
