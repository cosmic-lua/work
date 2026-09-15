--- Atomic create-once publication of a canonical saved attempt.
local fd = require("cosmic.fd")
local fs = require("cosmic.fs")
local rand = require("cosmic.rand")
local literal = require("_work.singlehead_literal")
--- Publish `raw` at `path` exactly once and durably: written to a private
--- temporary, fsynced, then hard-linked into place, so a path that already
--- holds an attempt fails rather than being overwritten and no reader ever sees
--- a half-written one. The directory is fsynced too, so the link survives a
--- crash. Create-once is the point: a second attempt at the same path would
--- make the first unverifiable.
--- @param path string The path to create
--- @param raw string The exact bytes to publish
--- @return boolean True when the path now holds these bytes
--- @return string Error message; "saved attempt already exists" for a collision
local function write_once(path: string, raw: string): boolean, string
  local directory = fs.dirname(path)
  local made, merr = fs.make_dirs(directory, fs.octal("700"))
  if not made then return false, merr end
  local temporary = fs.join(directory, "." .. fs.basename(path) .. "." .. rand.token())
  local handle, herr = fd.open(temporary, fd.O_WRONLY | fd.O_CREAT | fd.O_EXCL | fd.O_NOFOLLOW, fs.octal("400"))
  if handle == nil then return false, herr end
  local offset = 1
  while offset <= #raw do
    local n, werr = handle:write(raw:sub(offset))
    if n == nil or n == 0 then
      local _closed, _cerr = handle:close()
      local _removed, _rerr = fs.remove(temporary)
      return false, werr ~= "" and werr or "short saved-plan write"
    end
    offset = offset + n
  end
  local synced, serr = handle:sync()
  local closed, cerr = handle:close()
  if not synced or not closed then
    local _removed, _rerr = fs.remove(temporary)
    return false, not synced and serr or cerr
  end
  local linked, lerr = fs.link(temporary, path)
  local removed, rerr = fs.remove(temporary)
  if not linked then return false, fs.is_present(path) and "saved attempt already exists" or lerr end
  if not removed then return false, rerr end
  local dir, derr = fd.open(directory, fd.O_RDONLY | fd.O_DIRECTORY)
  if dir == nil then return false, derr end
  local dsynced, dserr = dir:sync()
  local dclosed, dcerr = dir:close()
  return dsynced and dclosed, not dsynced and dserr or dcerr
end
--- Save one canonical literal value through the same create-once boundary.
local function save_value(path: string, value: any): boolean, string
  local raw, err = literal.encode(value)
  if raw == nil then return false, err end
  return write_once(path, raw)
end

--- Load one canonical literal object, refusing alternate encodings.
local function load_value(path: string): {string: any} | nil, string
  local raw, err = fs.read(path)
  if raw == nil then return nil, err end
  local value, verr = literal.decode_object(raw)
  if value == nil then return nil, verr end
  if literal.encode(value) ~= raw then return nil, "saved value is not canonical" end
  return value, ""
end

local record Module
  save_value: function(string, any): boolean, string
  load_value: function(string): {string: any} | nil, string
end
local M: Module = {save_value = save_value, load_value = load_value}
return M
