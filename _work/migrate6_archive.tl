--- Durable source-ref witness for auditing the retired format-5 archive from
--- any fresh clone. Names are canonical refs/heads names, independent of the
--- private prefix the migration fetched into; this module never fetches.
local probes = require("_work.migrate6_probes")
local boardrefs = require("_work.refs")
local source = require("_work.migrate6_source")
local wire = require("_work.singlehead_literal")

local record Witness
  version: string
  refs: {string: string}
  absent: {string: string}
  probe_name: string
end

local function legacy_name(ref: string): boolean
  return ref:match("^refs/heads/items/.+") ~= nil
  or ref:match("^refs/heads/ended/.+") ~= nil
  or ref:match("^refs/heads/claim%-batches/.+") ~= nil
  or ref == "refs/heads/board/seq"
end

local function sha(value: any): boolean
  return value is string and #value == 40 and value:match("^[0-9a-f]+$") ~= nil
end

local function canonical(ref: string, prefix: string): string | nil
  if prefix:sub(1, 5) ~= "refs/" or prefix:sub(-1) ~= "/"
  or ref:sub(1, #prefix) ~= prefix then return nil end
  local name = "refs/heads/" .. ref:sub(#prefix + 1)
  return legacy_name(name) and name or nil
end

--- Strictly decode the source inventory and its exact prepared-probe identity.
local function decode(raw: string): Witness | nil, string
  local value, err = wire.decode_object(raw); if value == nil then return nil, err end
  local refs, absent, name = value.refs, value.absent, value.probe_name
  if value.version ~= "migrate6-sources-v1" or not (refs is {string: any})
  or not (absent is {string: any}) or not (name is string)
  or (name ~= "" and not name:match("^[%w%-]+$")) then
    return nil, "invalid migration source witness"
  end
  for field in pairs(value) do
    if field ~= "version" and field ~= "refs" and field ~= "absent"
    and field ~= "probe_name" then return nil, "unknown migration source witness field" end
  end
  local ref_out: {string: string} = {}
  for ref, tip in pairs(refs) do
    if not legacy_name(ref) or not sha(tip) then return nil, "invalid migration source ref" end
    ref_out[ref] = tip as string -- cast: sha validated the dynamic literal value
  end
  local absent_out: {string: string} = {}
  for ref, state in pairs(absent) do
    if not legacy_name(ref) or state ~= "absent" or ref_out[ref] ~= nil then
      return nil, "invalid absent migration source ref"
    end
    absent_out[ref] = "absent"
  end
  if name ~= "" then
    local absent_count = 0
    for _ in pairs(absent_out) do absent_count = absent_count + 1 end
    if absent_count ~= #probes.namespaces then
      return nil, "migration source witness has unexpected absent refs"
    end
    for _, namespace in ipairs(probes.namespaces) do
      for _, kind in ipairs({"update", "delete"}) do
        local ref = namespace .. name .. "-" .. kind
        if ref_out[ref] == nil then return nil, "migration source witness lacks prepared ref " .. ref end
      end
      local create = namespace .. name .. "-create"
      if absent_out[create] ~= "absent" then
        return nil, "migration source witness lacks absent ref " .. create
      end
    end
  elseif next(absent_out) ~= nil then return nil, "offline migration witness has absent refs" end
  return {version = "migrate6-sources-v1", refs = ref_out,
    absent = absent_out, probe_name = name}, ""
end

--- Build canonical archive inventory from the filtered source snapshot and,
--- for a frozen migration, the exact refs intentionally excluded from replay.
local function build(sources: {string: string}, prefix: string,
    manifest?: probes.Manifest): string | nil, string
  local refs: {string: string} = {}
  for ref, tip in pairs(sources) do
    local name = canonical(ref, prefix)
    if name == nil or not sha(tip) or refs[name] ~= nil then
      return nil, "invalid migration source inventory"
    end
    refs[name] = tip
  end
  local absent: {string: string} = {}
  local probe_name = ""
  if manifest ~= nil then
    probe_name = manifest.name
    for _, namespace in ipairs(probes.namespaces) do
      for _, kind in ipairs({"update", "delete"}) do
        local ref = manifest.refs[probes.key(kind, namespace)]
        if refs[ref] ~= nil then return nil, "prepared ref leaked into migration sources: " .. ref end
        refs[ref] = manifest.old_sha
      end
      local create = manifest.refs[probes.key("create", namespace)]
      if refs[create] ~= nil then return nil, "absent prepared ref is present: " .. create end
      absent[create] = "absent"
    end
  end
  local encoded, err = wire.encode({version = "migrate6-sources-v1",
      refs = refs, absent = absent, probe_name = probe_name})
  if encoded == nil then return nil, err end
  local _, checked = decode(encoded); if checked ~= "" then return nil, checked end
  return encoded, ""
end

--- The grouping key for a canonical legacy name: the namespace a wholly
--- absent bucket can be reported and re-fetched as one unit.
---
--- `refs/heads/board/seq` is a single ref, so "absent because never fetched"
--- and "absent because deleted" are indistinguishable for it; it returns nil
--- and keeps its per-ref line rather than claiming a cause it cannot know.
--- @param name string A canonical refs/heads name from the witness
--- @return string | nil The namespace without its trailing slash, or nil
local function namespace_of(name: string): string | nil
  for _, ns in ipairs({"refs/heads/items", "refs/heads/ended",
      "refs/heads/claim-batches"}) do
    if name:sub(1, #ns + 1) == ns .. "/" then return ns end
  end
  return nil
end

--- Compare a locally fetched legacy namespace with the durable witness. Every
--- missing, moved or added ref is named; exact absent probes are additions too.
---
--- A namespace with no local counterpart for ANY of its witness refs was never
--- fetched into this clone: the archive is frozen upstream by ruleset, so mass
--- deletion is not what a clone-local absence means. Such a bucket collapses to
--- one line naming the fetch, rather than one line per ref — a fresh checkout
--- would otherwise report every archived ref as removed. A bucket with even one
--- ref present is a genuine divergence and stays per-ref, and `moved` and
--- `added` are never collapsed.
local function problems(root: string, raw: string, prefix: string): {string}
  local witness, err = decode(raw)
  if witness == nil then return {"migration/sources: " .. err} end
  local local_refs, serr = source.snapshot(root, prefix)
  if local_refs == nil then return {"migration/sources: " .. serr} end
  local actual: {string: string} = {}
  for ref, tip in pairs(local_refs) do
    local name = canonical(ref, prefix)
    if name ~= nil then actual[name] = tip end
  end
  local total: {string: integer} = {}
  local present: {string: integer} = {}
  for ref in pairs(witness.refs) do
    local ns = namespace_of(ref)
    if ns ~= nil then
      total[ns] = (total[ns] or 0) + 1
      present[ns] = (present[ns] or 0) + (actual[ref] ~= nil and 1 or 0)
    end
  end
  local unfetched: {string: boolean} = {}
  local out: {string} = {}
  local remote = boardrefs.board_remote(root)
  for ns, count in pairs(total) do
    if present[ns] == 0 and count >= 2 then
      unfetched[ns] = true
      out[#out + 1] = ("archive: %s not fetched — %d of %d witness refs absent locally; fetch it: git fetch --atomic %s '+%s/*:%s%s/*'")
      :format(ns, count, count, remote, ns, prefix, ns:match("([^/]+)$"))
    end
  end
  for ref, tip in pairs(witness.refs) do
    local ns = namespace_of(ref)
    if ns ~= nil and unfetched[ns] then
      -- Its namespace already reported, as one line for the whole bucket.
    elseif actual[ref] == nil then out[#out + 1] = "archive: removed " .. ref
    elseif actual[ref] ~= tip then out[#out + 1] = "archive: moved " .. ref end
  end
  for ref in pairs(actual) do
    if witness.refs[ref] == nil then out[#out + 1] = "archive: added " .. ref end
  end
  table.sort(out)
  return out
end

local record Archive
  type Witness = Witness
  build: function({string: string}, string, probes.Manifest | nil): string | nil, string
  decode: function(string): Witness | nil, string
  problems: function(string, string, string): {string}
end
local M: Archive = {build = build, decode = decode, problems = problems}
return M
