--- One invocation's initial canonical snapshot and scoped Git batch reader.
--- The marker read and the first item read share the existing gitbatch process.
local cachedb = require("_work.cachedb")
local format = require("_work.format")
local gitbatch = require("_work.gitbatch")
local refs = require("_work.refs")
local record Start
  snapshot: {refs.RefEntry}
  reader: gitbatch.BatchSession | nil
  head: string
end

--- Release the scoped batch reader a startup snapshot held, once its consumer
--- has taken what it needs. Idempotent, and a no-op for a snapshot that never
--- opened one.
--- @param start Start | nil The snapshot to release, nil accepted
--- @return boolean True on success
--- @return string Error message
local function close(start: Start | nil): boolean, string
  if start == nil then return true, "" end
  local reader = start.reader
  start.reader = nil
  if reader ~= nil then return reader:close() end
  return true, ""
end

--- One invocation's opening read: the canonical ref snapshot, the board
--- format decided from the marker inside it, and — while the format is still
--- unknown — the `cat-file --batch` process that read the marker, kept open so
--- the first item read shares it instead of spawning its own. This is why
--- selecting the format costs a verb no process of its own.
--- @param root string The board checkout
--- @return Start | nil The snapshot, its head ("" on a legacy board) and reader
--- @return string Error message, including the format's own refusal
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

local record stateread_start
  type Start = Start
  open: function(root: string): Start | nil, string
  close: function(start: Start | nil): boolean, string
end
local M: stateread_start = {open = open, close = close}
return M
