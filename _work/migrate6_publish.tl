--- Shell-only migration publication. The CLI may render plans offline; an
--- executor must independently verify an owner-supplied freeze witness, fetch
--- the complete legacy refset, and recheck it immediately before --atomic.
local gitobj = require("_work.gitobj")
local migrate6 = require("_work.migrate6")
local source = require("_work.migrate6_source")

local record FreezeProof
  destination: string
  witness: string
  frozen_at: integer
end
local type Verifier = function(FreezeProof): boolean, string
local record Plan
  destination: string
  head: string
  marker: string
  stages: {{string}}
  activation: {string}
  prerequisites: {string}
end

local function remote_url(root: string, remote: string): string | nil, string
  if remote == "" or remote:sub(1, 1) == "-" or remote:find("[%c]") then
    return nil, "invalid migration remote"
  end
  local url, err = source.git(root, {"remote", "get-url", "--push", remote})
  if url == nil then return nil, err end
  return (url:gsub("%s+$", "")), ""
end

local function remote_refs(root: string, remote: string): {string: string} | nil, string
  local raw, err = source.git(root, {"ls-remote", "--refs", remote, "refs/heads/*"})
  if raw == nil then return nil, err end
  local out: {string: string} = {}
  for sha, ref in raw:gmatch("([0-9a-f]+)%s+([^%s]+)\n") do out[ref] = sha end
  return out, ""
end

local function legacy(refs: {string: string}, prefix: string): {string: string}
  local out: {string: string} = {}
  for ref, sha in pairs(refs) do
    local short = ref:sub(#prefix + 1)
    if ref:sub(1, #prefix) == prefix and (short:match("^items/")
      or short:match("^ended/") or short:match("^claim%-batches/") or short == "board/seq") then
      out["refs/heads/" .. short] = sha
    end
  end
  return out
end

local function marker(root: string, parent: string, date: string): string | nil, string
  if parent ~= "" then
    local existing = source.git(root, {"show", parent .. ":format"})
    if existing == "6\n" then return parent, "" end
  end
  local blob, err = gitobj.hash_object_write(root, "6\n")
  if blob == nil then return nil, err end
  local tree, terr = gitobj.mktree_write(root,
    {{mode = "100644", otype = "blob", name = "format", sha = blob}})
  if tree == nil then return nil, terr end
  local parents: {string} = {}
  if parent ~= "" then parents[1] = parent end
  return gitobj.commit_tree(root, {tree = tree, parents = parents,
      author_name = "gitboard", author_email = "gitboard@board", author_date = date,
      committer_name = "gitboard", committer_email = "gitboard@board", committer_date = date,
      message = "activate format 6", op = "migrate6"})
end

local function plan(root: string, cp: migrate6.Checkpoint, remote: string,
    limit: integer, marker_parent?: string, published_head?: string): Plan | nil, string
  if cp.phase ~= "planned" then return nil, "migration is not fully replayed" end
  if limit < 1 then return nil, "migration push limit must be positive" end
  local destination, err = remote_url(root, remote)
  if destination == nil then return nil, err end
  local identity, ierr = source.git(root, {"rev-parse", "--absolute-git-dir"})
  if identity == nil then return nil, ierr end
  if identity:gsub("%s+$", "") ~= cp.repository then return nil, "checkpoint repository differs" end
  local raw, rerr = source.git(root, {"rev-list", "--first-parent", "--reverse", cp.head})
  if raw == nil then return nil, rerr end
  local shas: {string} = {}
  local index: {string: integer} = {}
  for sha in raw:gmatch("[0-9a-f]+") do shas[#shas + 1], index[sha] = sha, #shas + 1 end
  local published = published_head or ""
  if published ~= "" and index[published] == nil then
    return nil, "destination state is not an ancestor of the frozen migration tip"
  end
  local from = index[published] or 0
  local stages: {{string}} = {}
  for n = limit, #shas - 1, limit do
    if n > from then stages[#stages + 1] = {"git", "push", destination,
        shas[n] .. ":refs/heads/state"} end
  end
  local date, derr = source.git(root, {"show", "-s", "--format=%ct", cp.head})
  if date == nil then return nil, derr end
  local parent = marker_parent
  if parent == nil then
    local found, ferr = source.git(root, {"for-each-ref", "--format=%(objectname)", cp.prefix .. "board/format"})
    if found == nil then return nil, ferr end
    parent = found:gsub("%s+$", "")
  end
  local mark, merr = marker(root, parent, date:gsub("%s+$", "") .. " +0000")
  if mark == nil then return nil, merr end
  return {destination = destination, head = cp.head, marker = mark, stages = stages,
    activation = {"git", "push", "--atomic", destination, cp.head .. ":refs/heads/state",
      mark .. ":refs/heads/board/format"}, prerequisites = {
      "Owner freezes creation, update, deletion of items/**, ended/**, claim-batches/**, board/seq with no bypass BEFORE snapshot.",
      "Independently verify a destination-bound ruleset witness; a boolean supplied by the CLI is not verification.",
      "Fetch and compare every legacy ref name and tip immediately before atomic shell activation.",
      "Connector activation is unavailable: state and marker must update in one atomic shell push."}}, ""
end

local function verify_sources(root: string, cp: migrate6.Checkpoint,
    remote: string): {string: string} | nil, string
  local destination, uerr = remote_url(root, remote)
  if destination == nil then return nil, uerr end
  -- Verification refs are isolated from board readers. --prune matters: the
  -- deletion of an item ref must not be hidden by a stale tracking ref.
  local fetched, err = source.git(root, {"fetch", "--no-tags", "--prune", destination,
      "+refs/heads/items/*:refs/gitboard/migrate6/verify/items/*",
      "+refs/heads/ended/*:refs/gitboard/migrate6/verify/ended/*",
      "+refs/heads/claim-batches/*:refs/gitboard/migrate6/verify/claim-batches/*",
      "+refs/heads/board/*:refs/gitboard/migrate6/verify/board/*",
      "+refs/heads/state:refs/gitboard/migrate6/verify-state"})
  if fetched == nil then
    -- A brand-new destination has no state yet. Fetch all heads to a private
    -- namespace instead; wildcards also tolerate the absent legacy seq ref.
    fetched, err = source.git(root, {"fetch", "--no-tags", "--prune", destination,
        "+refs/heads/*:refs/gitboard/migrate6/verify-all/*"})
    if fetched == nil then return nil, err end
  end
  local actual, aerr = remote_refs(root, destination)
  if actual == nil then return nil, aerr end
  local same, drift = source.compare(legacy(cp.sources, cp.prefix), legacy(actual, "refs/heads/"))
  if not same then return nil, drift end
  local complete, cerr = source.integrity(root, legacy(actual, "refs/heads/"))
  if not complete then return nil, cerr end
  return actual, ""
end

local function prepare_activation(root: string, cp: migrate6.Checkpoint, remote: string,
    limit: integer, proof: FreezeProof, verify: Verifier): Plan | nil, string
  local destination, err = remote_url(root, remote)
  if destination == nil then return nil, err end
  if proof.destination ~= destination or proof.witness == "" then
    return nil, "freeze witness must be bound to the exact push destination"
  end
  if proof.frozen_at <= 0 or proof.frozen_at > cp.snapshot_at then
    return nil, "freeze must be verified as effective before the source snapshot"
  end
  if verify == nil then return nil, "independent freeze verifier is required" end
  local frozen, ferr = verify(proof)
  if not frozen then return nil, "freeze verification refused: " .. ferr end
  local actual, aerr = verify_sources(root, cp, remote)
  if actual == nil then return nil, aerr end
  return plan(root, cp, remote, limit, actual["refs/heads/board/format"] or "",
    actual["refs/heads/state"] or "")
end

--- Deliberately separate from plan: no saved plan can bypass fresh guard
--- calls. This is the only function here that mutates a destination.
local function activate(root: string, cp: migrate6.Checkpoint, remote: string,
    proof: FreezeProof, verify: Verifier): boolean, string
  local p, err = prepare_activation(root, cp, remote, 1, proof, verify)
  if p == nil then return false, err end
  local args: {string} = {}
  for i = 2, #p.activation do args[#args + 1] = p.activation[i] end
  local result, rerr = source.git(root, args)
  if result == nil then return false, rerr end
  return true, ""
end

local function publish(root: string, cp: migrate6.Checkpoint, remote: string,
    limit: integer, proof: FreezeProof, verify: Verifier): boolean, string
  local p, err = prepare_activation(root, cp, remote, limit, proof, verify)
  if p == nil then return false, err end
  for _, stage in ipairs(p.stages) do
    local args: {string} = {}
    for i = 2, #stage do args[#args + 1] = stage[i] end
    local landed, lerr = source.git(root, args)
    if landed == nil then return false, lerr end
  end
  return activate(root, cp, remote, proof, verify)
end

local record Publish
  type FreezeProof = FreezeProof
  type Verifier = Verifier
  type Plan = Plan
  plan: function(root: string, cp: migrate6.Checkpoint, remote: string, limit: integer,
  marker_parent?: string, published_head?: string): Plan | nil, string
  prepare_activation: function(string, migrate6.Checkpoint, string, integer,
  FreezeProof, Verifier): Plan | nil, string
  activate: function(string, migrate6.Checkpoint, string, FreezeProof, Verifier): boolean, string
  publish: function(string, migrate6.Checkpoint, string, integer, FreezeProof, Verifier): boolean, string
  verify_sources: function(string, migrate6.Checkpoint, string): {string: string} | nil, string
end
local M: Publish = {plan = plan, prepare_activation = prepare_activation, activate = activate, publish = publish,
  verify_sources = verify_sources}
return M
