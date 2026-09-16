--- Pristine per-user runtime storage; execution always uses a private copy.
local env = require("cosmic.env")
local fd = require("cosmic.fd")
local fs = require("cosmic.fs")
local hash = require("cosmic.hash")
local rand = require("cosmic.rand")
local LIMIT < const > = 268435456

--- Read a bounded snapshot from one regular, non-symlink descriptor.
local function bytes(path: string, limit: integer): string | nil, string
  local h, err = fd.open(path, fd.O_RDONLY | fd.O_NOFOLLOW | fd.O_NONBLOCK)
  if h == nil then return nil, err end
  local st, serr = fs.stat_fd(h:fd())
  if st == nil or not st:is_file() or st:size() > limit then
    local _ok, _err = h:close()
    return nil, serr ~= "" and serr or "not a bounded regular file"
  end
  local parts: {string} = {}
  local size = 0
  while size <= limit do
    local part, rerr = h:read(math.min(65536, limit + 1 - size))
    if part == nil then
      local closed, cerr = h:close()
      if rerr ~= nil and rerr ~= "" then return nil, rerr end
      if not closed then return nil, cerr end
      return table.concat(parts), ""
    end
    size = size + #part
    parts[#parts + 1] = part
  end
  local _ok, _err = h:close()
  return nil, "file exceeds size limit"
end

local function verified(path: string, digest: string): string | nil, string
  local text, err = bytes(path, LIMIT)
  if text == nil then return nil, err end
  if hash.sha256_hex(text) ~= digest then return nil, "sha256 mismatch" end
  return text, ""
end

local function entry(digest: string): string | nil, string
  local base = env.get("XDG_CACHE_HOME") or ""
  if base:sub(1, 1) ~= "/" then
    local home = env.get("HOME") or ""
    if home:sub(1, 1) ~= "/" then return nil, "runtime shared caching unavailable: no absolute cache base" end
    base = home .. "/.cache"
  end
  return fs.join(base, "cosmic/runtime", digest, "cosmic.ape"), ""
end

local function ancestors(path: string, create: boolean): string
  local cursor = ""
  for part in fs.dirname(path):gmatch("[^/]+") do
    cursor = cursor .. "/" .. part
    local st = fs.stat_link(cursor)
    if st ~= nil then
      if not st:is_dir() then return "unsafe cache ancestor: " .. cursor end
    elseif create then
      local ok, err = fs.make_dir(cursor, fs.octal("700"))
      if not ok then
        st = fs.stat_link(cursor)
        if st == nil or not st:is_dir() then return err end
      end
    end
  end
  return ""
end

local function read(path: string, digest: string): string | nil, string
  local err = ancestors(path, false)
  if err ~= "" then return nil, err end
  return verified(path, digest)
end

local function winner(path: string, digest: string)
  local text, err = read(path, digest)
  if text == nil then print(("runtime cache publication rejected %q: %s"):format(path, err)) end
end

local function publish(path: string, digest: string, text: string): string
  local err = ancestors(path, true)
  if err ~= "" then return err end
  if fs.stat_link(path) ~= nil then winner(path, digest); return "" end
  local temporary = fs.join(fs.dirname(path), ".cosmic-" .. rand.token())
  local h, herr = fd.open(temporary, fd.O_WRONLY | fd.O_CREAT | fd.O_EXCL | fd.O_NOFOLLOW, fs.octal("600"))
  if h == nil then return herr end
  local offset = 1
  while offset <= #text do
    local count, werr = h:write(text:sub(offset))
    if count == nil or count == 0 then err = werr or "short write"; break end
    offset = offset + count
  end
  local closed, cerr = h:close()
  if not closed and err == "" then err = cerr end
  local linked, lerr = false, ""
  if err == "" then
    local staged, serr = verified(temporary, digest)
    if staged == nil then err = serr else linked, lerr = fs.link(temporary, path) end
  end
  local removed, rerr = fs.remove(temporary)
  if not removed then return "cache publication temporary cleanup failed: " .. rerr end
  if err ~= "" then return err end
  if not linked then
    local exists = "link: " .. temporary .. " -> " .. path .. ": EEXIST: "
    if lerr:sub(1, #exists) ~= exists then return lerr end
  end
  winner(path, digest)
  return ""
end

local record runtime_cache
  bytes: function(path: string, limit: integer): string | nil, string
  verified: function(path: string, digest: string): string | nil, string
  entry: function(digest: string): string | nil, string
  read: function(path: string, digest: string): string | nil, string
  publish: function(path: string, digest: string, text: string): string
end
local M: runtime_cache = {bytes = bytes, verified = verified, entry = entry, read = read, publish = publish}
return M
