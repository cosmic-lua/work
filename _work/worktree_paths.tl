--- Registered checkout metadata and safe sibling worktree placement.
local child = require("cosmic.child")
local fs = require("cosmic.fs")

local record Checkout
  path: string
  bare: boolean
end

local function registered(root: string): {Checkout} | nil, string
  local r, err = child.run({"git", "worktree", "list", "--porcelain", "-z"}, {cwd = root})
  if r == nil then return nil, err end
  if not r.ok then return nil, "cannot read registered worktrees: " .. r.stderr end
  local out: {Checkout} = {}
  for field in r.stdout:gmatch("([^%z]+)") do
    local path = field:match("^worktree (.+)$")
    if path ~= nil then out[#out + 1] = {path = path, bare = false}
    elseif field == "bare" and #out > 0 then out[#out].bare = true end
  end
  return out, ""
end

local function primary(root: string): string | nil, string
  local entries, err = registered(root)
  if entries == nil then return nil, err end
  local first = entries[1]
  if first == nil or first.bare or not fs.is_dir(first.path) then
    return nil, "no usable nonbare primary worktree for " .. root
  end
  local r = child.run({"git", "rev-parse", "--show-toplevel"}, {cwd = first.path})
  local path = fs.resolve(first.path)
  if r == nil or not r.ok or path == nil or fs.resolve((r.stdout:gsub("%s+$", ""))) ~= path then
    return nil, "no usable nonbare primary worktree for " .. root
  end
  local common: string | nil = nil
  for _, checkout in ipairs({root, path}) do
    local metadata = child.run({"git", "rev-parse", "--path-format=absolute", "--git-common-dir"}, {cwd = checkout})
    local resolved = metadata ~= nil and metadata.ok and fs.resolve((metadata.stdout:gsub("%s+$", ""))) or nil
    if resolved == nil or (common ~= nil and common ~= resolved) then
      return nil, "no usable nonbare primary worktree for " .. root
    end
    common = resolved
  end
  return path, ""
end

--- Resolve existing ancestors before appending a not-yet-created suffix.
local function destination(path: string): string | nil, string
  local current = fs.absolute_path(path)
  local suffix: {string} = {}
  while not fs.is_present(current) and not fs.is_link(current) do
    table.insert(suffix, 1, fs.basename(current))
    local parent = fs.dirname(current)
    if parent == current then return nil, "cannot resolve destination " .. path end
    current = parent
  end
  local resolved, err = fs.resolve(current)
  if resolved == nil then return nil, err end
  for _, part in ipairs(suffix) do resolved = fs.join(resolved, part) end
  return resolved, ""
end

local function refusal(root: string, path: string): string | nil
  local resolved, err = destination(path)
  if resolved == nil then return "cannot resolve destination " .. path .. ": " .. err end
  local entries, rerr = registered(root)
  if entries == nil then return rerr end
  for _, entry in ipairs(entries) do
    if not entry.bare then
      local other, oerr = destination(entry.path)
      if other == nil then return oerr end
      local prefix = other == "/" and other or other .. "/"
      if resolved == other or resolved:sub(1, #prefix) == prefix then
        return ("destination %s is equal to or beneath registered worktree %s")
        :format(path, entry.path)
      end
    end
  end
  return nil
end

local record worktree_paths
  primary: function(root: string): string | nil, string
  refusal: function(root: string, path: string): string | nil
end
local M: worktree_paths = {primary = primary, refusal = refusal}
return M
