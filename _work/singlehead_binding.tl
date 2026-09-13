--- Native checkout/provider identity checks for the experimental envelope.
--- Both fetch and push URLs must resolve uniquely to the configured GitHub
--- repository before any exact fetch or connector plan is rendered.
local child = require("cosmic.child")
local objects = require("_work.singlehead_objects")

local record Binding
  mode: string
  remote: string
  fetch_url: string
  push_url: string
  repository: string
  branch: string
end

local function valid_repository(repository: string): boolean
  local checked = objects.checked_repository(repository)
  return checked ~= nil
end

local function repository_from_url(url: string): string | nil, string
  local owner, name = url:match("^https://github%.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)/?$")
  if owner == nil then
    owner, name = url:match("^ssh://git@github%.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)/?$")
  end
  if owner == nil then
    owner, name = url:match("^git@github%.com:([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)/?$")
  end
  if name ~= nil then name = name:gsub("%.git$", "") end
  local repository = owner ~= nil and name ~= nil and owner .. "/" .. name or ""
  if not valid_repository(repository) then
    return nil, "board remote is not an unambiguous GitHub repository: " .. url
  end
  local canonical, cerr = objects.checked_repository(repository)
  if canonical == nil then return nil, cerr end
  return canonical, ""
end

local function one_url(root: string, remote: string,
    push: boolean): string | nil, string
  local argv = {"git", "remote", "get-url"}
  if push then argv[#argv + 1] = "--push" end
  argv[#argv + 1] = "--all"
  argv[#argv + 1] = remote
  local r, err = child.run(argv, {cwd = root})
  if r == nil then return nil, err end
  if not r.ok then
    return nil, ("transaction remote cannot be resolved: %s"):format(remote)
  end
  local urls: {string} = {}
  for url in r.stdout:gmatch("([^\n]+)") do urls[#urls + 1] = url end
  if #urls ~= 1 then
    return nil, ("remote %s must have exactly one %s URL"):format(remote,
      push and "push" or "fetch")
  end
  return urls[1], ""
end

local function inspect(root: string, remote: string,
    repository: string, branch: string): Binding | nil, string
  if remote == "" or remote:sub(1, 1) == "-"
  or remote:match("^[A-Za-z0-9._/-]+$") == nil
  or remote:find("..", 1, true) ~= nil or remote:sub(1, 1) == "/"
  or remote:sub(-1) == "/" then
    return nil, "remote name is not safe in a remote-tracking ref"
  end
  if not valid_repository(repository) then
    return nil, "repository must be an owner/name slug"
  end
  local checked_repository = objects.checked_repository(repository)
  if checked_repository == nil then return nil, "repository must be an owner/name slug" end
  local checked_branch, branch_err = objects.checked_branch(branch)
  if checked_branch == nil then return nil, branch_err end
  local fetch_url, ferr = one_url(root, remote, false)
  if fetch_url == nil then return nil, ferr end
  local push_url, perr = one_url(root, remote, true)
  if push_url == nil then return nil, perr end
  local fetch_repository, frerr = repository_from_url(fetch_url)
  if fetch_repository == nil then return nil, frerr end
  local push_repository, prerr = repository_from_url(push_url)
  if push_repository == nil then return nil, prerr end
  if fetch_repository ~= checked_repository then
    return nil, ("fetch remote targets %s, not destination %s")
    :format(fetch_repository, checked_repository)
  end
  if push_repository ~= checked_repository then
    return nil, ("push remote targets %s, not destination %s")
    :format(push_repository, checked_repository)
  end
  return {mode = "remote", remote = remote, fetch_url = fetch_url,
    push_url = push_url, repository = checked_repository, branch = checked_branch}, ""
end

local record singlehead_binding
  type Binding = Binding
  valid_repository: function(repository: string): boolean
  repository_from_url: function(url: string): string | nil, string
  inspect: function(root: string, remote: string,
  repository: string, branch: string): Binding | nil, string
end

local M: singlehead_binding = {
  valid_repository = valid_repository,
  repository_from_url = repository_from_url,
  inspect = inspect,
}

return M
