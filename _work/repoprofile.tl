--- Local command advertisements, not execution or artifact attestation.
--- Make discovery reads one bounded literal header; it never evaluates Make.
local child = require("cosmic.child")
local fs = require("cosmic.fs")

local enum Kind
  "cosmic"
  "make"
  "absent"
end

local record Profile
  kind: Kind
  bootstrap: {{string}}
  gate: {string}
  check_file: function(file: string): {string}
  test_file: function(file: string): {string}
end

local LIMIT < const > = 65536

local function profile(kind: Kind, capabilities: {string: boolean}): Profile
  if kind == "cosmic" then
    return {
      kind = kind,
      bootstrap = {{"bin/cosmic", "--make", "fetch"}, {"bin/cosmic", "--make", "build"}},
      gate = {"bin/cosmic", "--make", "ci"},
      check_file = function(file: string): {string}
        return {"bin/cosmic", "--check", "types", file}
      end,
      test_file = function(file: string): {string}
        return {"bin/cosmic", "--make", "test", file}
      end,
    }
  end
  local function command(target: string, file?: string): {string}
    if not capabilities[target] then return {} end
    local argv = {"make", "-f", "Makefile", target}
    if file ~= nil then argv[#argv + 1] = "FILE=" .. file end
    return argv
  end
  local bootstrap: {{string}} = {}
  if capabilities.bootstrap then bootstrap[1] = command("bootstrap") end
  return {kind = kind, bootstrap = bootstrap, gate = command("gate"),
    check_file = function(file: string): {string} return command("check-file", file) end,
    test_file = function(file: string): {string} return command("test-file", file) end}
end

--- Read once and close even if the read raises an I/O error.
local function prefix(path: string): string
  local file = io.open(path, "rb")
  if file == nil then return "" end
  local ok, content = pcall(function(): string
      return file:read(LIMIT + 1) or ""
    end)
  local closed, result = pcall(function(): boolean return file:close() ~= nil end)
  if ok and closed and result and content is string then return content end
  return ""
end

local function advertised(content: string): {string: boolean}
  local position = 1
  while position <= #content do
    local newline = content:find("\n", position, true)
    local ending = newline or #content
    if ending > LIMIT then return {} end
    local line = content:sub(position, newline and newline - 1 or ending)
    if newline and line:sub(-1) == "\r" then line = line:sub(1, -2) end
    if line:find("\0", 1, true) then return {} end
    if line:match("^[ \t]*#") then
      if line:match("\\[ \t]*$") then return {} end
    elseif not line:match("^[ \t]*$") then
      local tokens = line:match("^%.PHONY:[ \t]+(.-)[ \t]*$")
      if tokens == nil then return {} end
      local found: {string: boolean} = {}
      for token in tokens:gmatch("[^ \t]+") do
        if found[token] or (token ~= "bootstrap" and token ~= "gate"
          and token ~= "check-file" and token ~= "test-file") then return {} end
        found[token] = true
      end
      return found
    end
    if newline == nil then break end
    position = newline + 1
  end
  return {}
end

--- Resolve only this checkout's regular marker files. Plans are fresh argv
--- arrays; a caller must separately authorize execution with cwd=checkout.
--- @param checkout string Local checkout directory
--- @return Profile Advertised commands, or an absent profile on I/O failure
local function resolve(checkout: string): Profile
  if checkout == "" or not fs.is_dir(checkout) then return profile("absent", {}) end
  if fs.is_file(fs.join(checkout, "bin/cosmic")) then return profile("cosmic", {}) end
  local makefile = fs.join(checkout, "Makefile")
  if not fs.is_file(makefile) then return profile("absent", {}) end
  local capabilities = advertised(prefix(makefile))
  return profile(next(capabilities) ~= nil and "make" or "absent", capabilities)
end

--- Read only the cached origin/HEAD symbolic ref, independently of kind.
--- No default is guessed and no remote is queried; callers own fallback.
--- @param checkout string Local checkout directory
--- @return string Cached branch suffix, or "" when missing, failed or malformed
local function default_base(checkout: string): string
  if checkout == "" then return "" end
  local r = child.run({"git", "symbolic-ref", "-q", "refs/remotes/origin/HEAD"},
    {cwd = checkout})
  if r == nil or not r.ok then return "" end
  local value = r.stdout:gsub("\r?\n$", "", 1)
  local branch = value:match("^refs/remotes/origin/(.+)$")
  if branch == nil or branch:find("[%z\1-\32\127]") then return "" end
  return branch
end

local record repoprofile
  type Kind = Kind
  type Profile = Profile
  resolve: function(checkout: string): Profile
  default_base: function(checkout: string): string
end

local M: repoprofile = {
  resolve = resolve,
  default_base = default_base,
}
return M
