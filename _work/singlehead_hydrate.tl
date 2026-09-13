--- Validate one exact envelope archive, import its immutable packs, and
--- project its logical board refs into one canonical remote-tracking
--- namespace. The envelope ref check, monotonic materialization marker, and
--- every logical create/update/delete share one update-ref transaction.
local objects = require("_work.singlehead_objects")
local refs = require("_work.refs")

local MATERIALIZED_REF < const > = "refs/gitboard/single-head/materialized"

local record Result
  head: string
  refs: integer
  packs: integer
  changed: integer
end

local function valid_prefix(prefix: string): boolean
  local remote = prefix:match("^refs/remotes/([A-Za-z0-9._/-]+)/$")
  return remote ~= nil and remote:sub(1, 1) ~= "-"
  and remote:sub(1, 1) ~= "/" and remote:sub(-1) ~= "/"
  and remote:find("..", 1, true) == nil
end

local function tracking_ref(prefix: string, logical: string): string | nil
  local tail = logical:match("^refs/heads/(.+)$")
  if tail == nil then return nil end
  return prefix .. tail
end

local function current(root: string, prefix: string): {string: string} | nil, string
  local found, err = refs.for_each_ref_raw(root, {
      prefix .. "items/", prefix .. "ended/", prefix .. "board/",
      prefix .. "claim-batches/",
    })
  if found == nil then return nil, err end
  local out: {string: string} = {}
  for _, entry in ipairs(found) do out[entry.refname] = entry.sha end
  return out, ""
end

local function hydrate(root: string, head: string, prefix: string,
    envelope_ref: string, repository: string, branch: string): Result | nil, string
  if not valid_prefix(prefix) then
    return nil, "tracking prefix must be refs/remotes/REMOTE/"
  end
  if envelope_ref ~= prefix .. branch then
    return nil, "envelope ref differs from the bound tracking ref"
  end
  local archive, aerr = objects.read_validated_archive(root, head,
    repository, branch)
  if archive == nil then return nil, aerr end
  local materialized, merr = refs.read_ref(root, MATERIALIZED_REF)
  if materialized == nil then return nil, merr end
  if materialized ~= refs.ZERO_SHA
  and not refs.is_ancestor(root, materialized, head) then
    return nil, "refusing to regress the materialized envelope head"
  end
  local before, berr = current(root, prefix)
  if before == nil then return nil, berr end
  local after: {string: string} = {}
  for logical, sha in pairs(archive.state.refs) do
    local projected = tracking_ref(prefix, logical)
    if projected == nil then return nil, "archive contains a non-board ref" end
    after[projected] = sha
  end
  for _, packed in ipairs(archive.packs) do
    local imported, ierr = objects.index_pack(root, packed)
    if not imported then return nil, ierr end
  end
  local updates: {refs.RefUpdate} = {}
  local changed = 0
  for ref, old in pairs(before) do
    local next_sha = after[ref] or refs.ZERO_SHA
    if old ~= next_sha then
      updates[#updates + 1] = {ref = ref, expected = old, next = next_sha}
      changed = changed + 1
    end
  end
  for ref, next_sha in pairs(after) do
    if before[ref] == nil then
      updates[#updates + 1] = {ref = ref, expected = refs.ZERO_SHA,
        next = next_sha}
      changed = changed + 1
    end
  end
  if materialized ~= head then
    updates[#updates + 1] = {ref = MATERIALIZED_REF,
      expected = materialized, next = head}
  end
  table.sort(updates, function(a: refs.RefUpdate, b: refs.RefUpdate): boolean
      return a.ref < b.ref
    end)
  local applied, apply_err = refs.update_refs_atomic(root, updates,
    {{ref = envelope_ref, expected = head}})
  if not applied then return nil, apply_err end
  local count = 0
  for _ in pairs(after) do count = count + 1 end
  return {head = head, refs = count, packs = #archive.packs,
    changed = changed}, ""
end

local record singlehead_hydrate
  MATERIALIZED_REF: string
  type Result = Result
  hydrate: function(root: string, head: string, prefix: string,
  envelope_ref: string, repository: string, branch: string): Result | nil, string
end

local M: singlehead_hydrate = {
  MATERIALIZED_REF = MATERIALIZED_REF,
  hydrate = hydrate,
}

return M
