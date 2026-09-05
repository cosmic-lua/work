--- One `git cat-file --batch` process, fed successive rounds of
--- queries over its own stdin pipe and read back over its stdout
--- stream, for a caller (`_work.gitread.load`/`.list`,
--- `_work.gitreadmany.load_many`) whose read is a fixed handful of
--- DEPENDENT rounds — one process serves the whole read rather than
--- one per round. Split out of `_work.gitobj` (whose `cat_file_batch`
--- wraps `batch_session` for its one-shot form) and `_work.gitread`,
--- both already at the repo's line cap, so the mechanism has room.
local child = require("cosmic.child")
local fd = require("cosmic.fd")

--- One object a session's `request` (or `_work.gitobj.cat_file_batch`)
--- read back.
local record BatchEntry
  otype: string -- "blob" | "tree" | "commit"
  size: integer
  content: string
end

--- A round's queries are written in bounded CHUNKS, each chunk's
--- answers fully drained before the next is written — never the whole
--- round up front (fills both the request and response pipes at once
--- on a large round, with neither side draining: a deadlock no small
--- fixture shows), and never one query per answer either (serializes
--- one pipe round trip per query — thousands of them on a real
--- board). A chunk's request lines stay well under a pipe's buffer, so
--- git can read all of them before it needs to write any answer.
local CHUNK_QUERIES < const > = 64

--- One `git cat-file --batch` process, answering one round of queries
--- at a time — one process for a caller's several DEPENDENT rounds.
local record BatchSession
  _handle: child.Handle
  _writer: fd.Handle
  _buf: string
  _closed: boolean
  --- One round: blocks until every query has its answer, a missing object included, without crossing into a later round's bytes.
  --- @param queries {string} Rev specs to read, may be empty
  --- @return {string: BatchEntry} | nil One entry per query git could resolve
  --- @return string Error message
  request: function(self: BatchSession, queries: {string}): {string: BatchEntry} | nil, string
  --- Send stdin EOF and reap the process; idempotent, even after a failed `request`.
  --- @return boolean
  --- @return string Error message
  close: function(self: BatchSession): boolean, string
end

--- Attach BatchSession's methods to an already-started process and its stdin pipe's writer end.
--- @param handle child.Handle The started `git cat-file --batch`
--- @param writer fd.Handle This session's own end of its stdin pipe
--- @return BatchSession
local function make_session(handle: child.Handle, writer: fd.Handle): BatchSession
  local sess: BatchSession = {_handle = handle, _writer = writer, _buf = "", _closed = false}

  function sess:request(queries: {string}): {string: BatchEntry} | nil, string
    if #queries == 0 then
      return {}
    end
    local out: {string: BatchEntry} = {}
    local i = 1
    while i <= #queries do
      local last = math.min(i + CHUNK_QUERIES - 1, #queries)
      local lines: {string} = {}
      for j = i, last do
        lines[#lines + 1] = queries[j]
      end
      local line = table.concat(lines, "\n") .. "\n"
      local off = 0
      while off < #line do
        local n, werr = self._writer:write(line:sub(off + 1))
        if n == nil then
          return nil, werr
        end
        off = off + n
      end
      for j = i, last do
        local query = queries[j]
        while true do
          local nl = self._buf:find("\n", 1, true)
          if nl ~= nil then
            local header = self._buf:sub(1, nl - 1)
            if header:match(" missing$") then
              self._buf = self._buf:sub(nl + 1)
              break
            end
            local otype, size_s = header:match("^%S+ (%S+) (%d+)$")
            if otype == nil then
              return nil, ("cat-file --batch: unparseable header: %s"):format(header)
            end
            local size = math.tointeger(tonumber(size_s))
            if #self._buf >= nl + size + 1 then
              out[query] = {otype = otype, size = size, content = self._buf:sub(nl + 1, nl + size)}
              self._buf = self._buf:sub(nl + size + 2) -- past the object's own trailing "\n"
              break
            end
          end
          local chunk, rerr = self._handle:read()
          if chunk == nil then
            return nil, rerr or "cat-file --batch: unexpected eof"
          end
          self._buf = self._buf .. chunk
        end
      end
      i = last + 1
    end
    return out
  end

  function sess:close(): boolean, string
    if self._closed then
      return true
    end
    self._closed = true
    local _wok, _werr = self._writer:close()
    local _r, werr = self._handle:wait()
    if werr ~= nil then
      return false, werr
    end
    return true
  end

  return sess
end

--- Start one `git cat-file --batch` process for several dependent rounds (`request`), closed by the caller when done (`close`).
--- @param root string The repository root
--- @return BatchSession | nil
--- @return string Error message
local function batch_session(root: string): BatchSession | nil, string
  -- CLOEXEC, or the child's un-dup'd writer copy survives into git and
  -- keeps the pipe open, so closing OUR writer never reaches EOF.
  local p, perr = fd.pipe(fd.O_CLOEXEC)
  if p == nil then
    return nil, perr
  end
  local h, herr = child.start({"git", "cat-file", "--batch"}, {cwd = root, stdin = p.reader})
  if h == nil then
    local _ok, _err = p:close()
    return nil, herr
  end
  -- The child holds its own dup2'd copy; only this session's writer decides EOF.
  local _rok, _rerr = p.reader:close()
  return make_session(h, p.writer)
end

--- Close a session and forward a round's failure, so an early return never leaves the process running.
--- @param sess BatchSession The session to close
--- @param err string The error to forward
--- @return nil
--- @return string The same error
local function session_fail(sess: BatchSession, err: string): nil, string
  local _ok, _err = sess:close()
  return nil, err
end

local record gitbatch
  type BatchEntry = BatchEntry
  type BatchSession = BatchSession
  batch_session: function(root: string): BatchSession | nil, string
  session_fail: function(sess: BatchSession, err: string): nil, string
end

local M: gitbatch = {
  batch_session = batch_session,
  session_fail = session_fail,
}

return M
