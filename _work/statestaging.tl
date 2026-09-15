--- Destination identity for snapshot publication.
local child = require("cosmic.child")

--- The exact push URL for the remote, or an empty string when it has none.
local function target_url(root: string, remote: string): string
  local result = child.run({"git", "remote", "get-url", "--push", remote},
    {cwd = root})
  if result == nil or not result.ok then return "" end
  return (result.stdout:gsub("%s+$", ""))
end

--- The configured publication repository, a repository derived from the
--- remote URL, or the local-board identity when neither is available.
local function repository(root: string, remote: string): string
  local configured = child.run(
    {"git", "config", "--get", "gitboard.publicationRepository"}, {cwd = root})
  if configured ~= nil and configured.ok then
    return (configured.stdout:gsub("%s+$", ""))
  end
  local url = child.run({"git", "remote", "get-url", remote}, {cwd = root})
  if url ~= nil and url.ok then
    local name = url.stdout:gsub("%s+$", ""):gsub("%.git$", "")
    :match("[:/]([^/:]+/[^/]+)$")
    if name ~= nil then return name end
  end
  return "local/board"
end

local record Module
  target_url: function(string, string): string
  repository: function(string, string): string
end

local M: Module = {target_url = target_url, repository = repository}
return M
