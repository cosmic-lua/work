--- Small object and destination primitives shared by native publication.
local hash = require("cosmic.hash")
local git = require("_work.singlehead_git")

local ZERO < const > = string.rep("0", 40)

--- @return The lowercase owner/name slug, or a refusal.
local function checked_repository(value: any): string | nil, string
  if not (value is string)
  or value:match("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$") == nil then
    return nil, "repository must be an owner/name GitHub slug"
  end
  return value:lower(), ""
end

--- @return A valid branch name, never a full ref or legacy board namespace.
local function checked_branch(value: any): string | nil, string
  if not (value is string) or value == "" or value:sub(1, 5) == "refs/" then
    return nil, "branch must be a branch name, not a ref"
  end
  for _, reserved in ipairs({"items", "ended", "board", "claims", "claim-batches"}) do
    if value == reserved or value:sub(1, #reserved + 1) == reserved .. "/" then
      return nil, "publication branch collides with a board namespace"
    end
  end
  local ok = git.probe(".", {"check-ref-format", "refs/heads/" .. value})
  if not ok then return nil, "invalid publication branch" end
  return value, ""
end

--- @return A full lowercase SHA-1 object id, optionally including all zeroes.
local function checked_sha(value: any, allow_zero?: boolean): string | nil, string
  if not (value is string) or #value ~= 40 or value:match("^[0-9a-f]+$") == nil
  or (value == ZERO and not allow_zero) then
    return nil, "not a supported object ID: " .. tostring(value)
  end
  return value, ""
end

local function sha256(bytes: string): string
  return hash.sha256_hex(bytes)
end

local record TreeElement
  path: string
  mode: string
  otype: string
  content: string
end

--- Test and fixture constructor for one flat tree.
local function make_tree(repo: string, elements: {TreeElement},
    base_tree?: string): string | nil, string
  local args: {string} = {"mktree"}
  local rows: {string} = {}
  if base_tree ~= nil then
    local listing, err = git.run(repo, {"ls-tree", base_tree})
    if listing == nil then return nil, err end
    for row in listing:gmatch("([^\n]+)") do rows[#rows + 1] = row end
  end
  for _, element in ipairs(elements) do
    local blob, err = git.text(repo, {"hash-object", "-w", "--stdin"}, element.content)
    if blob == nil then return nil, err end
    rows[#rows + 1] = element.mode .. " " .. element.otype .. " " .. blob .. "\t" .. element.path
  end
  table.sort(rows)
  return git.text(repo, args, #rows > 0 and table.concat(rows, "\n") .. "\n" or "")
end

--- Test and fixture constructor for a commit with stable fallback identity.
local function make_commit(repo: string, tree: string, message: string,
    parent?: string): string | nil, string
  local args: {string} = {"commit-tree", tree}
  if parent ~= nil then args[#args + 1], args[#args + 2] = "-p", parent end
  return git.text(repo, args, message, {
      GIT_AUTHOR_NAME = "Gitboard Test", GIT_AUTHOR_EMAIL = "test@board",
      GIT_AUTHOR_DATE = "1700000000 +0000", GIT_COMMITTER_NAME = "Gitboard Test",
      GIT_COMMITTER_EMAIL = "test@board", GIT_COMMITTER_DATE = "1700000000 +0000"})
end

local record Module
  type TreeElement = TreeElement
  checked_repository: function(any): string | nil, string
  checked_branch: function(any): string | nil, string
  checked_sha: function(any, allow_zero?: boolean): string | nil, string
  sha256: function(string): string
  make_tree: function(string, {TreeElement}, base_tree?: string): string | nil, string
  make_commit: function(string, string, string, parent?: string): string | nil, string
end

local M: Module = {checked_repository = checked_repository,
  checked_branch = checked_branch, checked_sha = checked_sha, sha256 = sha256,
  make_tree = make_tree, make_commit = make_commit}
return M
