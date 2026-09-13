--- Binary-safe Git subprocess boundary for the single-head transport.
--- Every invocation disables replacement objects and lazy promisor fetches.
local child = require("cosmic.child")
local env = require("cosmic.env")

local OBJECT_ENV < const >: {string} = {
  "GIT_ALTERNATE_OBJECT_DIRECTORIES", "GIT_OBJECT_DIRECTORY",
  "GIT_COMMON_DIR", "GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE",
  "GIT_SHALLOW_FILE", "GIT_REPLACE_REF_BASE",
}

local function argv_for(root: string, args: {string}): {string}
  local argv: {string} = {"git", "--no-replace-objects", "-C", root}
  for _, argument in ipairs(args) do argv[#argv + 1] = argument end
  return argv
end

local function environment(set?: {string: string}, isolated?: boolean): {string}
  local values: {string: string} = {GIT_NO_LAZY_FETCH = "1"}
  for key, value in pairs(set or {}) do values[key] = value end
  return env.list({drop = isolated and OBJECT_ENV or {}, set = values})
end

--- Run Git and preserve stdout as arbitrary binary bytes.
local function run(root: string, args: {string}, stdin?: string,
    set?: {string: string}, isolated?: boolean): string | nil, string
  local result, err = child.run(argv_for(root, args), {
      stdin = stdin or "", env = environment(set, isolated),
    })
  if result == nil then return nil, err end
  if not result.ok then
    local detail = result.stderr ~= "" and result.stderr or result.stdout
    local cleaned = detail:gsub("%s+$", "")
    return nil, cleaned
  end
  return result.stdout, ""
end

--- Probe Git without turning an ordinary nonzero status into a module error.
local function probe(root: string, args: {string}, stdin?: string,
    set?: {string: string}, isolated?: boolean): boolean, string, string
  local result, err = child.run(argv_for(root, args), {
      stdin = stdin or "", env = environment(set, isolated),
    })
  if result == nil then return false, "", err end
  local cleaned = result.stderr:gsub("%s+$", "")
  return result.ok, result.stdout, cleaned
end

local function text(root: string, args: {string}, stdin?: string,
    set?: {string: string}, isolated?: boolean): string | nil, string
  local out, err = run(root, args, stdin, set, isolated)
  if out == nil then return nil, err end
  return out:gsub("%s+$", ""), ""
end

local function oid(root: string, name: string): string | nil, string
  return text(root, {"rev-parse", "--verify", name})
end

local record SingleHeadGit
  run: function(root: string, args: {string}, stdin?: string,
  set?: {string: string}, isolated?: boolean): string | nil, string
  probe: function(root: string, args: {string}, stdin?: string,
  set?: {string: string}, isolated?: boolean): boolean, string, string
  text: function(root: string, args: {string}, stdin?: string,
  set?: {string: string}, isolated?: boolean): string | nil, string
  oid: function(root: string, name: string): string | nil, string
end

local M: SingleHeadGit = {run = run, probe = probe, text = text, oid = oid}
return M
