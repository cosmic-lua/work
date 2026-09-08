--- Explicit local product-repository mapping for commit verification.
---
--- Mappings are checkout-local Git configuration, repeated values of:
---
---   git config --local --add gitboard.repository owner/name=/absolute/path
---
--- A command's explicit override wins. No sibling search, clone, fetch,
--- remote probe, provider API, credential helper, or environment token is
--- consulted here.
local child = require("cosmic.child")
local fs = require("cosmic.fs")

--- Check that a selected path is a local Git work tree.
--- @param path string Candidate local repository
--- @return string | nil Canonical-enough path for Git operations
--- @return string Error message
local function validate(path: string): string | nil, string
  if path == "" then return nil, "repository path is empty" end
  if not fs.is_dir(path) then
    return nil, ("repository path is not a directory: %s"):format(path)
  end
  local r, err = child.run(
    {"git", "rev-parse", "--show-toplevel"}, {cwd = path})
  if r == nil then return nil, err end
  if not r.ok then
    return nil, ("repository path is not a Git work tree: %s"):format(path)
  end
  -- A directory nested inside some enclosing checkout also satisfies
  -- `--show-toplevel`; it is not itself the explicitly selected checkout.
  -- Require the selected directory to be that work tree's root so a typo or
  -- stale mapping cannot silently verify commits in the board repository.
  local prefix, perr = child.run(
    {"git", "rev-parse", "--show-prefix"}, {cwd = path})
  if prefix == nil then return nil, perr end
  if not prefix.ok or prefix.stdout:gsub("%s+$", "") ~= "" then
    return nil, ("repository path is not a Git work tree root: %s"):format(path)
  end
  return (r.stdout:gsub("%s+$", "")), ""
end

--- Resolve a repository identity to a caller-managed local checkout.
--- `override` wins when non-empty. Otherwise the board checkout's repeated
--- `gitboard.repository` values are scanned for an exact owner/name mapping.
--- @param board_root string Local board checkout
--- @param repository string Product repository identity (`owner/name`)
--- @param override string Per-command local path, "" for configured mapping
--- @return string | nil Local Git work tree
--- @return string Error message
local function resolve(board_root: string, repository: string,
    override: string): string | nil, string
  if override ~= "" then return validate(override) end
  if repository == "" then return nil, "item has no repository identity" end
  local r, err = child.run(
    {"git", "config", "--local", "--get-all", "gitboard.repository"},
    {cwd = board_root})
  if r == nil then return nil, err end
  -- Exit 1 is the ordinary "no values" result from git config.
  if not r.ok and r.code ~= 1 then
    return nil, ("cannot read repository mappings: %s"):format(r.stderr)
  end
  for line in r.stdout:gmatch("([^\n]+)") do
    local identity, path = line:match("^([^=]+)=(.+)$")
    if identity == repository then return validate(path) end
  end
  return nil, ("no local repository mapped for %s — configure one with "
    .. "`git config --local --add gitboard.repository %s=/absolute/path` "
    .. "or pass --repo-dir"):format(repository, repository)
end

local record repository_map
  validate: function(path: string): string | nil, string
  resolve: function(board_root: string, repository: string,
  override: string): string | nil, string
end

local M: repository_map = {
  validate = validate,
  resolve = resolve,
}

return M
