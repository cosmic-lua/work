--- The exact fetch argv native publication and refresh execute. Every
--- refspec is explicit and forced into the configured remote's tracking
--- namespace; nothing here runs Git, so a caller renders before it
--- authorizes execution.
local repoprofile = require("_work.repoprofile")

--- The board's state and format refs from `remote`.
local function fetch_argv(remote: string): {string}
  return {"git", "fetch", "--atomic", remote,
    "+refs/heads/state:refs/remotes/" .. remote .. "/state",
    "+refs/heads/board/format:refs/remotes/" .. remote .. "/board/format"}
end

--- The publication branch `branch` from `endpoint` (the remote by default)
--- into `remote`'s canonical state tracking ref, plus the format ref.
local function fetch_branch_argv(remote: string, branch: string,
    endpoint?: string): {string}
  return {"git", "fetch", "--atomic", endpoint or remote,
    "+refs/heads/" .. branch .. ":refs/remotes/" .. remote .. "/state",
    "+refs/heads/board/format:refs/remotes/" .. remote .. "/board/format"}
end

--- `fetch_branch_argv` plus the board remote's default branch, so a session
--- that starts with `refresh --execute` holds a current `<remote>/<default>`
--- for board-repository items before its first claim compares against it.
--- The default is the cached `origin/HEAD` that `repoprofile.default_base`
--- reads for the board checkout at `root`; a checkout with none cached adds
--- nothing, and so does one whose default already lands in a tracking ref
--- the argv fetches (a board whose HEAD is its state branch), since one
--- fetch may not update the same ref twice.
local function refresh_argv(root: string, remote: string, branch: string,
    endpoint?: string): {string}
  local argv = fetch_branch_argv(remote, branch, endpoint)
  local default = repoprofile.default_base(root)
  if default == "" then return argv end
  local destination = ":refs/remotes/" .. remote .. "/" .. default
  for _, refspec in ipairs(argv) do
    if refspec:sub(-#destination) == destination then return argv end
  end
  argv[#argv + 1] = "+refs/heads/" .. default .. destination
  return argv
end

local record snapshot_fetch
  fetch_argv: function(remote: string): {string}
  fetch_branch_argv: function(remote: string, branch: string,
  endpoint?: string): {string}
  refresh_argv: function(root: string, remote: string, branch: string,
  endpoint?: string): {string}
end

local M: snapshot_fetch = {
  fetch_argv = fetch_argv,
  fetch_branch_argv = fetch_branch_argv,
  refresh_argv = refresh_argv,
}
return M
