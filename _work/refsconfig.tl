--- Checkout-local board mode and remote selection.
local child = require("cosmic.child")

local enum BoardMode
  "local"
  "remote"
end

-- Canonical reads consult these values repeatedly. Cache repository config so
-- one board operation does not spawn a `git config` process per ref lookup.
local MODE_BY_ROOT: {string: BoardMode} = {}
local REMOTE_BY_ROOT: {string: string} = {}

local function board_remote(root: string): string
  local known = REMOTE_BY_ROOT[root]
  if known ~= nil then return known end
  local configured = child.run({"git", "config", "--get", "gitboard.remote"},
    {cwd = root})
  if configured ~= nil and configured.ok then
    local value = configured.stdout:gsub("%s+$", "")
    if value ~= "" then
      REMOTE_BY_ROOT[root] = value
      return value
    end
  end
  REMOTE_BY_ROOT[root] = "origin"
  return "origin"
end

--- Select a remote for this process without changing repository config.
local function use_remote(root: string, remote: string): boolean, string
  if remote == "" or remote:match("^[%w._/-]+$") == nil
  or remote:find("..", 1, true) ~= nil or remote:sub(1, 1) == "/"
  or remote:sub(-1) == "/" then
    return false, "remote name is not safe in a remote-tracking ref"
  end
  REMOTE_BY_ROOT[root] = remote
  return true, ""
end

--- Persist the canonical remote in checkout-local Git configuration.
local function set_board_remote(root: string, remote: string): boolean, string
  local valid, verr = use_remote(root, remote)
  if not valid then return false, verr end
  local r, err = child.run({"git", "config", "gitboard.remote", remote},
    {cwd = root})
  if r == nil then return false, err end
  if not r.ok then
    return false, ("git config gitboard.remote failed: %s"):format(r.stderr)
  end
  return true, ""
end

--- Read the explicit board mode, retaining legacy inference for migration.
local function board_mode(root: string): BoardMode
  local known = MODE_BY_ROOT[root]
  if known ~= nil then return known end
  local configured = child.run({"git", "config", "--get", "gitboard.mode"},
    {cwd = root})
  if configured ~= nil and configured.ok then
    local value = configured.stdout:gsub("%s+$", "")
    if value == "remote" then
      MODE_BY_ROOT[root] = "remote"
      return "remote"
    end
    if value == "local" then
      MODE_BY_ROOT[root] = "local"
      return "local"
    end
  end
  local remotes = child.run({"git", "remote"}, {cwd = root})
  local mode: BoardMode = remotes ~= nil and remotes.ok
  and remotes.stdout:match("%S") ~= nil and "remote" or "local"
  MODE_BY_ROOT[root] = mode
  return mode
end

--- Persist an explicit board mode. This changes only `.git/config`.
local function set_board_mode(root: string, mode: BoardMode): boolean, string
  local r, err = child.run({"git", "config", "gitboard.mode", mode},
    {cwd = root})
  if r == nil then return false, err end
  if not r.ok then
    return false, ("git config gitboard.mode failed: %s"):format(r.stderr)
  end
  MODE_BY_ROOT[root] = mode
  return true, ""
end

local record refsconfig
  type BoardMode = BoardMode
  board_mode: function(root: string): BoardMode
  set_board_mode: function(root: string, mode: BoardMode): boolean, string
  board_remote: function(root: string): string
  use_remote: function(root: string, remote: string): boolean, string
  set_board_remote: function(root: string, remote: string): boolean, string
end

local M: refsconfig = {
  board_mode = board_mode,
  set_board_mode = set_board_mode,
  board_remote = board_remote,
  use_remote = use_remote,
  set_board_remote = set_board_remote,
}
return M
