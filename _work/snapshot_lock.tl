--- Clone-wide serialization for snapshot proposal and recovery transitions.
---
--- The lock file is persistent so every opener addresses one inode.  The
--- kernel releases its advisory lock when a process exits; file existence is
--- never interpreted as ownership.  POSIX record locks are process-scoped, so
--- the table also refuses a nested transition in this Lua process.
local fd = require("cosmic.fd")
local fs = require("cosmic.fs")
local git = require("_work.singlehead_git")

local active: {string: boolean} = {}

local record Lock
  metamethod __close: function(self: Lock)
  close: function(self: Lock): boolean, string
end

local function common_dir(root: string): string | nil, string
  local common, err = git.text(root,
    {"rev-parse", "--path-format=absolute", "--git-common-dir"})
  if common == nil then return nil, err end
  local resolved, rerr = fs.resolve(common)
  if resolved == nil then return nil, rerr end
  return resolved, ""
end

local function path(root: string): string | nil, string
  local common, err = common_dir(root)
  if common == nil then return nil, err end
  return fs.join(common, "gitboard/snapshot.lock"), ""
end

local function acquire(root: string): Lock | nil, string
  local lock_path, perr = path(root)
  if lock_path == nil then return nil, perr end
  if active[lock_path] then
    return nil, "snapshot state transition is already active in this process"
  end
  local made, merr = fs.make_dirs(fs.dirname(lock_path), fs.octal("700"))
  if not made then return nil, merr end
  local handle, herr = fd.open(lock_path,
    fd.O_RDWR | fd.O_CREAT | fd.O_CLOEXEC, fs.octal("600"))
  if handle == nil then return nil, herr end
  local held, lerr = handle:fcntl(fd.F_SETLK, fd.F_WRLCK)
  if held == nil then
    local _closed, _cerr = handle:close()
    return nil, "another snapshot state transition is active: " .. lerr
  end
  active[lock_path] = true
  local open = true
  local lock: Lock = {}
  function lock:close(): boolean, string
    if not open then return true, "" end
    open = false
    active[lock_path] = nil
    local unlocked, uerr = handle:fcntl(fd.F_SETLK, fd.F_UNLCK)
    local closed, cerr = handle:close()
    if unlocked == nil then return false, uerr end
    return closed, cerr
  end
  return setmetatable(lock, {
      __close = function(self: Lock) local _ok, _err = self:close() end
    }), ""
end

local record Module
  type Lock = Lock
  common_dir: function(string): string | nil, string
  path: function(string): string | nil, string
  acquire: function(string): Lock | nil, string
end

local M: Module = {common_dir = common_dir, path = path, acquire = acquire}
return M
