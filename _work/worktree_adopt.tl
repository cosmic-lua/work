--- Exact claim-bound checkout validation, shared by fresh and adopted preparation.
local child = require("cosmic.child")
local claim = require("_work.claim")
local fs = require("cosmic.fs")
local receipt = require("_work.preparation_receipt")
local repository_map = require("_work.repository_map")
local store = require("_work.store")

local record Context
  s: store.Store
  id: string
  session: string
  initial: claim.State
  source: string
  branch: string
  path: string
  expected: string
end

local function git(path: string, argv: {string}): string, string
  local r, err = child.run({"git", table.unpack(argv)}, {cwd = path})
  if r == nil then return "", "could not run git: " .. err end
  if not r.ok then
    return "", ("git failed (signal=%s, exit=%s): %s"):format(tostring(r.signal), tostring(r.code), r.stderr)
  end
  return r.stdout, ""
end

local function value(path: string, argv: {string}): string, string
  local text, err = git(path, argv)
  return (text:gsub("%s+$", "")), err
end

local function checkout(c: Context): string
  local measured, err = repository_map.validate(c.path)
  if measured ~= c.path then return "checkout is not its exact Git toplevel: " .. err end
  local canonical, cerr = fs.resolve(c.path)
  if canonical ~= c.path then return "checkout alias or symlink path: " .. (cerr or "") end
  local head, herr = value(c.path, {"rev-parse", "--verify", "HEAD^{commit}"})
  local branch, berr = value(c.path, {"symbolic-ref", "--short", "HEAD"})
  if head ~= c.expected then return "checkout HEAD does not equal requested commit: " .. herr end
  if branch ~= c.branch then return "checkout branch does not equal claim branch: " .. berr end
  local common, serr = value(c.source, {"rev-parse", "--path-format=absolute", "--git-common-dir"})
  if common == "" then return "source common directory unavailable: " .. serr end
  local other, oerr = value(c.path, {"rev-parse", "--path-format=absolute", "--git-common-dir"})
  if other ~= common then return "checkout common directory mismatch: " .. oerr end
  local registered, rerr = git(c.source, {"worktree", "list", "--porcelain", "-z"})
  if rerr ~= "" then return rerr end
  local found = false
  for entry in registered:gmatch("(.-)%z%z") do
    local path = entry:match("^worktree ([^%z]+)%z")
    local oid = entry:match("%zHEAD ([^%z]+)%z")
    local ref = (entry .. "\0"):match("%zbranch ([^%z]+)%z")
    if path == c.path and oid == c.expected and ref == "refs/heads/" .. c.branch then found = true end
  end
  if not found then return "checkout is not registered at exact path/branch/HEAD" end
  local status, sterr = git(c.path, {"status", "--porcelain=v1", "-z", "--untracked-files=no",
      "--ignore-submodules=none"})
  if sterr ~= "" then return sterr end
  if status ~= "" then return "checkout has dirty index or tracked files (including submodules)" end
  for _, key in ipairs({"GIT_AUTHOR_IDENT", "GIT_COMMITTER_IDENT"}) do
    local r, ierr = child.run({"git", "var", key}, {cwd = c.path})
    if r == nil or not r.ok then
      return ("%s unavailable in %s: %s; configure user.name and user.email "
        .. "with `git -C %q config --local KEY VALUE`, use that checkout's "
        .. "--worktree scope, or provide intentional Git identity environment overrides")
      :format(key, c.path, r ~= nil and r.stderr or ierr, c.path)
    end
  end
  return ""
end

--- Reload Git-backed authority, allowing only renewal of the same acquisition.
--- @return claim.State | nil Current confirmed state for receipt output
--- @return string Refusal
local function recheck(c: Context): claim.State | nil, string
  local it, err = store.load(c.s, c.id)
  if it == nil then return nil, err end
  local current, cerr = receipt.confirmed(c.s, it, c.session)
  if current == nil then return nil, cerr end
  if current.root ~= c.initial.root or current.holder ~= c.initial.holder
  or current.product_base ~= c.initial.product_base then return nil, "claim acquisition changed during preparation" end
  local invalid = checkout(c)
  if invalid ~= "" then return nil, invalid end
  return current, ""
end

--- @return string Refusal, empty for the canonical explicit adoption path
local function requested(c: Context, path: string): string
  if path ~= c.path then return "--adopt must equal the current claim's exact path: " .. c.path end
  local current, err = recheck(c)
  return current ~= nil and "" or err
end

local record worktree_adopt
  type Context = Context
  recheck: function(c: Context): claim.State | nil, string
  requested: function(c: Context, path: string): string
end
local M: worktree_adopt = {recheck = recheck, requested = requested}
return M
