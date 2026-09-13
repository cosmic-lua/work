--- Checkout-local opt-in for the experimental single-head connector backend.
--- An absent marker means the production multi-ref transport is unchanged.
local child = require("cosmic.child")

local MARKER < const > = "gitboard-single-head-v1"

local record Config
  remote: string
  repository: string
  branch: string
end

local function get(root: string, key: string): string
  local r = child.run({"git", "config", "--local", "--get", key},
    {cwd = root})
  if r == nil or not r.ok then return "" end
  return (r.stdout:gsub("%s+$", ""))
end

local function enabled(root: string): boolean
  return get(root, "gitboard.experimentalSingleHead") == MARKER
end

local function command_guard(root: string, command: string,
    explicit_remote?: string): string
  if not enabled(root) then return "" end
  if explicit_remote ~= nil and explicit_remote ~= "" then
    return "--remote cannot change an active single-head binding"
  end
  if command == "init" then return "init cannot rewrite an active experimental single-head checkout; use a fresh checkout" end
  if command == "migrate" then return "legacy multi-ref migration is disabled by the configured experimental single-head backend" end
  if command == "publish" or command == "refresh" or command == "sync" then
    return "this checkout uses the experimental single-head backend; use `gitboard single-head publish-plan` or `gitboard single-head refresh`"
  end
  return ""
end

local function mutation_needs_draft(root: string, command: string,
    selected_draft: string, log_add: boolean): boolean
  if not enabled(root) or selected_draft ~= "" then return false end
  return command == "new" or command == "attach" or command == "rank"
  or command == "set" or command == "spec" or command == "depend"
  or command == "undepend" or command == "take" or command == "verdict"
  or command == "done" or (command == "log" and log_add)
end

local function read(root: string): Config | nil, string
  if not enabled(root) then
    return nil, "single-head transport is not configured; run `gitboard single-head configure` explicitly"
  end
  local config: Config = {
    remote = get(root, "gitboard.remote"),
    repository = get(root, "gitboard.singleHead.repository"),
    branch = get(root, "gitboard.singleHead.branch"),
  }
  if get(root, "gitboard.mode") ~= "remote" then
    return nil, "active single-head configuration requires gitboard.mode=remote"
  end
  if config.remote == "" or config.repository == "" or config.branch == ""
  then
    return nil, "single-head configuration is incomplete"
  end
  return config, ""
end

local function write(root: string, config: Config): boolean, string
  local values: {string: string} = {
    ["gitboard.remote"] = config.remote,
    ["gitboard.mode"] = "remote",
    ["gitboard.singleHead.repository"] = config.repository,
    ["gitboard.singleHead.branch"] = config.branch,
    ["gitboard.experimentalSingleHead"] = MARKER,
  }
  -- Activate first so any later config-write failure leaves legacy transport
  -- guarded. This POC deliberately requires a fresh checkout to recover an
  -- incomplete binding rather than opening a split-brain escape hatch.
  local order = {"gitboard.experimentalSingleHead", "gitboard.remote", "gitboard.mode",
    "gitboard.singleHead.repository", "gitboard.singleHead.branch"}
  for _, key in ipairs(order) do
    local r, err = child.run({"git", "config", "--local", key, values[key]},
      {cwd = root})
    if r == nil then return false, err end
    if not r.ok then
      return false, ("git config %s failed: %s"):format(key,
        (r.stderr:gsub("%s+$", "")))
    end
  end
  return true, ""
end

local record gitsinglehead_config
  type Config = Config
  enabled: function(root: string): boolean
  command_guard: function(root: string, command: string,
  explicit_remote?: string): string
  mutation_needs_draft: function(root: string, command: string,
  selected_draft: string, log_add: boolean): boolean
  read: function(root: string): Config | nil, string
  write: function(root: string, config: Config): boolean, string
end

local M: gitsinglehead_config = {
  enabled = enabled,
  command_guard = command_guard,
  mutation_needs_draft = mutation_needs_draft,
  read = read,
  write = write,
}

return M
