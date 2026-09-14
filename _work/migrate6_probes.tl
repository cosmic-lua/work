--- Sacrificial legacy refs prepared before the migration freeze is enabled.
--- The manifest is durable before its first push, so an interrupted prepare
--- resumes by comparing exact remote tips instead of inventing another set.
local fs = require("cosmic.fs")
local hash = require("cosmic.hash")
local ksuid = require("cosmic.ksuid")
local wire = require("_work.singlehead_literal")
local source = require("_work.migrate6_source")

local NAMESPACES < const >: {string} = {
  "refs/heads/items/", "refs/heads/ended/", "refs/heads/claim-batches/",
}

local record Manifest
  version: string
  destination: string
  old_sha: string
  new_sha: string
  name: string
  status: string
  refs: {string: string}
  receipts: {string: string}
end

--- A push returns true only when the remote accepted it.
local type Pusher = function(string, string, {string}): boolean, string
--- A reader returns the exact tips among the requested full ref names.
local type Reader = function(string, string, {string}): {string: string} | nil, string

local function key(kind: string, namespace: string): string
  return kind .. " " .. namespace
end

local function names(manifest: Manifest): {string}
  local out: {string} = {}
  for _, namespace in ipairs(NAMESPACES) do
    for _, kind in ipairs({"create", "update", "delete"}) do
      out[#out + 1] = manifest.refs[key(kind, namespace)]
    end
  end
  return out
end

local function push(root: string, url: string, args: {string}): boolean, string
  local argv: {string} = {"push", "--porcelain", url}
  for _, value in ipairs(args) do argv[#argv + 1] = value end
  local out, err = source.git(root, argv)
  if out == nil then return false, (err:gsub("%s+$", "")) end
  return true, (out:gsub("%s+$", ""))
end

local function read_remote(root: string, url: string, refs: {string}): {string: string} | nil, string
  local argv: {string} = {"ls-remote", "--refs", url}
  for _, ref in ipairs(refs) do argv[#argv + 1] = ref end
  local raw, err = source.git(root, argv)
  if raw == nil then return nil, "cannot read sacrificial refs: " .. err end
  local wanted: {string: boolean} = {}
  for _, ref in ipairs(refs) do wanted[ref] = true end
  local out: {string: string} = {}
  for sha, ref in raw:gmatch("([0-9a-f]+)%s+([^%s]+)\n") do
    if not wanted[ref] or out[ref] ~= nil then return nil, "unexpected sacrificial ref listing" end
    out[ref] = sha
  end
  return out, ""
end

local function valid_sha(value: any): boolean
  return value is string and #value == 40 and value:match("^[0-9a-f]+$") ~= nil
end

--- Decode only the one manifest shape this module writes.
local function decode(raw: any): Manifest | nil, string
  if not (raw is {string: any}) then return nil, "freeze probe manifest must be an object" end
  local version, old_sha, new_sha = raw.version, raw.old_sha, raw.new_sha
  local destination, name, status = raw.destination, raw.name, raw.status
  local refs, receipts = raw.refs, raw.receipts
  if not (destination is string) or not (name is string) or not (status is string)
  or not (refs is {string: any}) or not (receipts is {string: any})
  or not (version is string) or not (old_sha is string) or not (new_sha is string)
  or version ~= "migrate6-freeze-probes-v1" or not valid_sha(old_sha)
  or not valid_sha(new_sha) or old_sha == new_sha
  or destination == "" or not name:match("^[%w%-]+$")
  or (status ~= "planned" and status ~= "seeded") then
    return nil, "invalid freeze probe manifest fields"
  end
  local refs_out: {string: string} = {}
  for _, namespace in ipairs(NAMESPACES) do
    for _, kind in ipairs({"create", "update", "delete"}) do
      local k = key(kind, namespace)
      local ref = refs[k]
      if not (ref is string) or ref ~= namespace .. name .. "-" .. kind then
        return nil, "freeze probe manifest has an unowned ref"
      end
      refs_out[k] = ref
    end
  end
  for k in pairs(refs) do
    local known = false
    for _, namespace in ipairs(NAMESPACES) do
      for _, kind in ipairs({"create", "update", "delete"}) do
        if k == key(kind, namespace) then known = true end
      end
    end
    if not known then return nil, "freeze probe manifest has an unknown ref" end
  end
  local receipts_out: {string: string} = {}
  for ref, sha in pairs(receipts) do
    if not (ref is string) or not (sha is string) or sha ~= old_sha then
      return nil, "freeze probe receipt has a changed tip"
    end
    local owned = false
    for _, namespace in ipairs(NAMESPACES) do
      if ref == refs[key("update", namespace)]
      or ref == refs[key("delete", namespace)] then owned = true end
    end
    if not owned then return nil, "freeze probe receipt names an unowned ref" end
    receipts_out[ref] = sha
  end
  if status == "seeded" and next(receipts) == nil then
    return nil, "seeded freeze probe manifest lacks receipts"
  end
  return {version = version, destination = destination, old_sha = old_sha,
    new_sha = new_sha, name = name, status = status, refs = refs_out,
    receipts = receipts_out}, ""
end

local function read(path: string): Manifest | nil, string
  local raw, err = fs.read(path); if raw == nil then return nil, err end
  local value, derr = wire.decode(raw); if value == nil then return nil, derr end
  return decode(value)
end

local function write(path: string, manifest: Manifest): boolean, string
  local encoded, err = wire.encode(manifest); if encoded == nil then return false, err end
  local made, merr = fs.make_dirs(fs.dirname(path)); if not made then return false, merr end
  return fs.write(path, encoded, {atomic = true})
end

--- Make a second commit object without moving any local ref. It has HEAD's
--- tree and HEAD as parent, so update probes transfer no new tree content.
local function second_commit(root: string, old: string): string | nil, string
  local tree, terr = source.git(root, {"rev-parse", old .. "^{tree}"})
  if tree == nil then return nil, terr end
  tree = tree:gsub("%s+$", "")
  local raw = "tree " .. tree .. "\nparent " .. old ..
  "\nauthor gitboard <gitboard@board> 1 +0000\n" ..
  "committer gitboard <gitboard@board> 1 +0000\n\nmigrate6 freeze update probe\n"
  local sha, err = source.git(root, {"hash-object", "-t", "commit", "-w", "--stdin"}, raw)
  if sha == nil then return nil, err end
  return sha:gsub("%s+$", ""), ""
end

--- Write the complete plan before pushing, then idempotently seed the update
--- and delete refs. Existing refs are accepted only at the planned old tip.
local function prepare(root: string, url: string, path: string,
    pusher?: Pusher, reader?: Reader): Manifest | nil, string
  local manifest: Manifest = nil
  if fs.is_present(path) then
    local loaded, err = read(path); if loaded == nil then return nil, err end
    if loaded.destination ~= url then return nil, "freeze probe manifest destination differs" end
    manifest = loaded
  else
    local old, oerr = source.git(root, {"rev-parse", "HEAD"}); if old == nil then return nil, oerr end
    old = old:gsub("%s+$", "")
    local new, nerr = second_commit(root, old); if new == nil then return nil, nerr end
    local name = "migrate6-freeze-probe-" .. ksuid.new()
    local refs: {string: string} = {}
    for _, namespace in ipairs(NAMESPACES) do
      for _, kind in ipairs({"create", "update", "delete"}) do
        refs[key(kind, namespace)] = namespace .. name .. "-" .. kind
      end
    end
    manifest = {version = "migrate6-freeze-probes-v1", destination = url,
      old_sha = old, new_sha = new, name = name, status = "planned", refs = refs, receipts = {}}
    local saved, serr = write(path, manifest); if not saved then return nil, serr end
  end
  local get, send = reader or read_remote, pusher or push
  local tips, rerr = get(root, url, names(manifest)); if tips == nil then return nil, rerr end
  local missing: {string} = {}
  for _, namespace in ipairs(NAMESPACES) do
    local create = manifest.refs[key("create", namespace)]
    if tips[create] ~= nil then return nil, "sacrificial create ref already exists: " .. create end
    for _, kind in ipairs({"update", "delete"}) do
      local ref = manifest.refs[key(kind, namespace)]
      if tips[ref] == nil then missing[#missing + 1] = manifest.old_sha .. ":" .. ref
      elseif tips[ref] ~= manifest.old_sha then return nil, "sacrificial ref moved: " .. ref end
    end
  end
  if #missing > 0 then
    local accepted, detail = send(root, url, missing)
    if not accepted then return nil, "cannot seed sacrificial refs before freeze: " .. detail end
  end
  tips, rerr = get(root, url, names(manifest)); if tips == nil then return nil, rerr end
  local receipts: {string: string} = {}
  for _, namespace in ipairs(NAMESPACES) do
    local create = manifest.refs[key("create", namespace)]
    if tips[create] ~= nil then return nil, "sacrificial create ref already exists: " .. create end
    for _, kind in ipairs({"update", "delete"}) do
      local ref = manifest.refs[key(kind, namespace)]
      if tips[ref] ~= manifest.old_sha then return nil, "sacrificial ref was not seeded exactly: " .. ref end
      receipts[ref] = manifest.old_sha
    end
  end
  manifest.status, manifest.receipts = "seeded", receipts
  local saved, serr = write(path, manifest); if not saved then return nil, serr end
  return manifest, ""
end

local function digest(manifest: Manifest): string | nil, string
  local encoded, err = wire.encode(manifest); if encoded == nil then return nil, err end
  return hash.sha256_hex(encoded), ""
end

--- Verify all prepared tips before a probe. The missing creation refs and the
--- existing update/delete refs make the three remote operations unambiguous.
local function verify(root: string, manifest: Manifest, reader?: Reader): boolean, string
  if manifest.status ~= "seeded" then return false, "freeze probe manifest is not seeded" end
  local tips, err = (reader or read_remote)(root, manifest.destination, names(manifest))
  if tips == nil then return false, err end
  for _, namespace in ipairs(NAMESPACES) do
    local create = manifest.refs[key("create", namespace)]
    if tips[create] ~= nil then return false, "sacrificial create ref exists: " .. create end
    for _, kind in ipairs({"update", "delete"}) do
      local ref = manifest.refs[key(kind, namespace)]
      if tips[ref] ~= manifest.old_sha or manifest.receipts[ref] ~= manifest.old_sha then
        return false, "sacrificial ref missing or moved: " .. ref
      end
    end
  end
  return true, ""
end

--- Remove only exact manifest-owned refs from the fetched source map. Any
--- similarly named or differently tipped ref remains visible to migration.
local function filter(refs: {string: string}, prefix: string,
    manifest: Manifest): {string: string} | nil, string
  local out: {string: string} = {}
  for ref, sha in pairs(refs) do out[ref] = sha end
  for _, namespace in ipairs(NAMESPACES) do
    for _, kind in ipairs({"update", "delete"}) do
      local remote_ref = manifest.refs[key(kind, namespace)]
      local local_ref = prefix .. remote_ref:sub(#"refs/heads/" + 1)
      if out[local_ref] ~= manifest.old_sha then
        return nil, "fetched sacrificial ref missing or moved: " .. remote_ref
      end
      out[local_ref] = nil
    end
  end
  return out, ""
end

local record Probes
  type Manifest = Manifest
  type Pusher = Pusher
  type Reader = Reader
  decode: function(any): Manifest | nil, string
  read: function(string): Manifest | nil, string
  prepare: function(string, string, string, Pusher | nil, Reader | nil): Manifest | nil, string
  verify: function(string, Manifest, Reader | nil): boolean, string
  filter: function({string: string}, string, Manifest): {string: string} | nil, string
  digest: function(Manifest): string | nil, string
  push: function(string, string, {string}): boolean, string
  key: function(string, string): string
  namespaces: {string}
end
local M: Probes = {decode = decode, read = read, prepare = prepare, verify = verify,
  filter = filter, digest = digest, push = push, key = key, namespaces = NAMESPACES}
return M
