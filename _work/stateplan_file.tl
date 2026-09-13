--- Atomic create-once publication of a canonical saved attempt.
local fd = require("cosmic.fd")
local fs = require("cosmic.fs")
local rand = require("cosmic.rand")
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
local record Module
  write_once: function(string, string): boolean, string
end
local M: Module = {write_once = write_once}
return M
