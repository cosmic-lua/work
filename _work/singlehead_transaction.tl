--- Freeze one publishable transaction and its checkout/provider binding.
--- The mutable staging ref is resolved exactly once; all subsequent reads use
--- that immutable commit SHA. Generic prepared transactions predate durable
--- remote metadata and are deliberately refused.
local child = require("cosmic.child")
local claimbatch = require("_work.claimbatch")
local gitobj = require("_work.gitobj")
local itemtree = require("_work.itemtree")
local objects = require("_work.singlehead_objects")
local binding = require("_work.singlehead_binding")
local refs = require("_work.refs")

local record Anchor
  ref: string
  sha: string
end

local record Frozen
  transaction_sha: string
  transaction: string
  staging_ref: string
  mode: string
  remote: string
  updates: {objects.Update}
  source: binding.Binding
end

local record Parsed
  mode: string
  remote: string
  updates: {objects.Update}
end

local function run(root: string, argv: {string}): string | nil, string
  local r, err = child.run(argv, {cwd = root})
  if r == nil then return nil, err end
  if not r.ok then
    local detail = (r.stderr ~= "" and r.stderr or r.stdout):gsub("%s+$", "")
    return nil, detail
  end
  local stdout = r.stdout:gsub("%s+$", "")
  return stdout, ""
end

local function safe_remote(remote: string): boolean
  return remote ~= "" and remote:sub(1, 1) ~= "-"
  and remote:sub(1, 1) ~= "/" and remote:sub(-1) ~= "/"
  and remote:find("..", 1, true) == nil
  and remote:match("^[A-Za-z0-9._/-]+$") ~= nil
end

local function parse_prepared(text: string): Parsed | nil, string
  local first, body = text:match("^([^\n]+)\n\n(.*)$")
  if first ~= "gitboard-prepared-v1" then return nil, "unsupported prepared transaction" end
  local raw: {objects.Update} = {}
  for line in body:gmatch("([^\n]+)") do
    local expected, next_sha, ref = line:match("^(%S+) (%S+) (%S+)$")
    if expected == nil then return nil, "malformed prepared transaction update" end
    raw[#raw + 1] = {ref = ref, expected = expected, next = next_sha}
  end
  local updates, err = objects.checked_updates(raw)
  if updates == nil then return nil, err end
  local lines: {string} = {"gitboard-prepared-v1", ""}
  for _, update in ipairs(updates) do
    lines[#lines + 1] = ("%s %s %s"):format(update.expected, update.next, update.ref)
  end
  if table.concat(lines, "\n") .. "\n" ~= text then
    return nil, "prepared transaction manifest is not canonical"
  end
  return {mode = "remote", remote = "", updates = updates}, ""
end

local function parse_draft(text: string): Parsed | nil, string
  local first, body = text:match("^([^\n]+)\n\n(.*)$")
  if first ~= "gitboard-draft-v1" then return nil, "unsupported draft transaction" end
  local mode, remote = "", ""
  local anchors: {Anchor} = {}
  local raw: {objects.Update} = {}
  for line in body:gmatch("([^\n]+)") do
    local kind, tail = line:match("^(%S+) (.*)$")
    if kind == "mode" then
      if mode ~= "" then return nil, "draft manifest has duplicate mode" end
      mode = tail
    elseif kind == "remote" then
      if remote ~= "" then return nil, "draft manifest has duplicate remote" end
      remote = tail
    elseif kind == "anchor" then
      local sha, ref = tail:match("^(%S+) (%S+)$")
      if sha == nil then return nil, "malformed draft anchor" end
      anchors[#anchors + 1] = {ref = ref, sha = sha}
    elseif kind == "update" then
      local expected, next_sha, ref = tail:match("^(%S+) (%S+) (%S+)$")
      if expected == nil then return nil, "malformed draft update" end
      raw[#raw + 1] = {ref = ref, expected = expected, next = next_sha}
    else
      return nil, "malformed draft manifest line: " .. line
    end
  end
  if mode ~= "remote" then return nil, "local-mode draft cannot be published to an envelope remote" end
  if not safe_remote(remote) then return nil, "draft manifest lacks a safe remote" end
  local seen: {string: boolean} = {}
  for _, anchor in ipairs(anchors) do
    local ref, rerr = objects.checked_ref(anchor.ref)
    local sha, serr = objects.checked_sha(anchor.sha, false)
    if ref == nil then return nil, rerr end
    if sha == nil then return nil, serr end
    if seen[ref] then return nil, "duplicate draft anchor" end
    if ref:find("/claim-batches/", 1, true) then return nil, "draft anchor is not a board ref" end
    seen[ref] = true
  end
  table.sort(anchors, function(a: Anchor, b: Anchor): boolean return a.ref < b.ref end)
  local updates, err = objects.checked_updates(raw)
  if updates == nil then return nil, err end
  local lines: {string} = {"gitboard-draft-v1", "", "mode " .. mode, "remote " .. remote}
  for _, anchor in ipairs(anchors) do lines[#lines + 1] = "anchor " .. anchor.sha .. " " .. anchor.ref end
  for _, update in ipairs(updates) do
    lines[#lines + 1] = ("update %s %s %s"):format(update.expected, update.next, update.ref)
  end
  if table.concat(lines, "\n") .. "\n" ~= text then
    return nil, "draft transaction manifest is not canonical"
  end
  return {mode = mode, remote = remote, updates = updates}, ""
end

local function parent_shas(content: string): {string}
  local out: {string} = {}
  local header = content:match("^(.-)\n\n") or ""
  for line in header:gmatch("([^\n]+)") do
    local parent = line:match("^parent ([0-9a-f]+)$")
    if parent ~= nil then out[#out + 1] = parent end
  end
  return out
end

--- Validate the batch object and both directions of every batch/member bridge.
local function claim_deadline(root: string,
    updates: {objects.Update}): integer | nil, string
  local batch_update: objects.Update | nil = nil
  for _, update in ipairs(updates) do
    if update.ref:match("^refs/heads/claim%-batches/") then
      if batch_update ~= nil then return nil, "one claim batch per transaction" end
      batch_update = update
    end
  end
  if batch_update == nil then return 0, "" end
  if batch_update.expected ~= refs.ZERO_SHA then return nil, "claim batches are append-only" end
  local batch, berr = claimbatch.read(root, batch_update.next)
  if batch == nil then return nil, "prepared claim has an invalid batch manifest: " .. berr end
  local suffix = batch_update.ref:match("/([^/]+)$") or ""
  if batch.id ~= suffix then return nil, "claim batch identity mismatch" end
  if batch.created_at <= 0 or batch.publish_by < 0
  or (batch.action ~= "drop" and batch.publish_by == 0)
  or (batch.action == "drop" and batch.publish_by ~= 0) then
    return nil, "invalid claim deadline"
  end
  if batch.action ~= "take" and batch.action ~= "renew" and batch.action ~= "drop" then
    return nil, "invalid claim batch action"
  end
  local queries: {string} = {batch.commit}
  for _, update in ipairs(updates) do
    if update ~= batch_update then
      queries[#queries + 1] = update.next
      queries[#queries + 1] = update.next .. ":meta"
    end
  end
  local got, gerr = gitobj.cat_file_batch(root, queries)
  if got == nil then return nil, gerr end
  if got[batch.commit] == nil or #parent_shas(got[batch.commit].content) ~= 0 then
    return nil, "claim batch must be parentless"
  end
  local matched: {string: boolean} = {}
  for _, row in ipairs(batch.rows) do
    local found: objects.Update | nil = nil
    for _, update in ipairs(updates) do
      if update.ref == "refs/heads/items/" .. row.id
      or update.ref == "refs/heads/ended/" .. row.id then
        if found ~= nil then return nil, "duplicate claim member bridge: " .. row.id end
        found = update
      end
    end
    if found == nil or found.expected ~= row.item_tip then
      return nil, "claim transaction missing member bridge: " .. row.id
    end
    local commit, meta = got[found.next], got[found.next .. ":meta"]
    if commit == nil or commit.otype ~= "commit" or meta == nil or meta.otype ~= "blob" then
      return nil, "unreadable claim bridge: " .. row.id
    end
    local parents = parent_shas(commit.content)
    local values = itemtree.parse_meta(meta.content)
    if #parents ~= 1 or parents[1] ~= row.item_tip
    or values.claim_batch ~= batch.commit then
      return nil, "claim bridge does not point to batch/base: " .. row.id
    end
    matched[found.ref] = true
  end
  if #batch.rows == 0 or #updates ~= #batch.rows + 1 then
    return nil, "claim transaction has extraneous or missing updates"
  end
  for _, update in ipairs(updates) do
    if update ~= batch_update and not matched[update.ref] then
      return nil, "claim transaction has extraneous update: " .. update.ref
    end
  end
  return batch.publish_by, ""
end

local function configured_remote(root: string): string
  local value, _err = run(root, {"git", "config", "--get", "gitboard.remote"})
  return value ~= nil and value ~= "" and value or "origin"
end

local function source_binding(source: string, remote: string,
    repository: string, branch: string, mode?: string): binding.Binding | nil, string
  if mode ~= nil and mode ~= "remote" then
    return nil, "local-mode draft cannot be published to an envelope remote"
  end
  return binding.inspect(source, remote, repository, branch)
end

local function inspect(source: string, staging_ref: string, repository: string,
    branch: string): Frozen | nil, string
  local kind = staging_ref:match("^refs/gitboard/(prepared)/[A-Za-z0-9_-]+$")
  or staging_ref:match("^refs/gitboard/(drafts)/[A-Za-z0-9_-]+$")
  if kind == nil then return nil, "name a prepared or draft staging ref explicitly" end
  local manifest, merr = refs.read_ref(source, staging_ref)
  if manifest == nil or manifest == refs.ZERO_SHA then
    return nil, merr ~= "" and merr or "transaction staging ref disappeared"
  end
  local exact, eerr = gitobj.cat_file_batch(source, {manifest, manifest .. ":manifest"})
  if exact == nil then return nil, eerr end
  local commit, blob = exact[manifest], exact[manifest .. ":manifest"]
  if commit == nil or commit.otype ~= "commit" or blob == nil or blob.otype ~= "blob" then
    return nil, "unreadable transaction manifest"
  end
  local parsed: Parsed | nil
  local perr: string
  if kind == "drafts" then
    parsed, perr = parse_draft(blob.content)
  else
    parsed, perr = parse_prepared(blob.content)
  end
  if parsed == nil then return nil, perr end
  if kind == "prepared" then
    local batch_sha = ""
    for _, update in ipairs(parsed.updates) do
      if update.ref:match("^refs/heads/claim%-batches/") then batch_sha = update.next end
    end
    if batch_sha == "" then
      return nil, "prepared transaction lacks immutable remote binding; use a remote-mode draft"
    end
    local deadline, derr = claim_deadline(source, parsed.updates)
    if deadline == nil then return nil, derr end
    local batch, berr = claimbatch.read(source, batch_sha)
    if batch == nil then return nil, berr end
    parsed.remote = batch.remote
  end
  if configured_remote(source) ~= parsed.remote then
    return nil, "transaction was prepared for a different board remote"
  end
  local source_identity, serr = source_binding(source, parsed.remote,
    repository, branch, parsed.mode)
  if source_identity == nil then return nil, serr end
  return {transaction_sha = manifest, transaction = manifest,
    staging_ref = staging_ref, mode = parsed.mode, remote = parsed.remote,
    updates = parsed.updates, source = source_identity}, ""
end

local record singlehead_transaction
  type Frozen = Frozen
  source_binding: function(source: string, remote: string,
  repository: string, branch: string, mode?: string): binding.Binding | nil, string
  claim_deadline: function(root: string,
  updates: {objects.Update}): integer | nil, string
  inspect: function(source: string, staging_ref: string,
  repository: string, branch: string): Frozen | nil, string
end

local M: singlehead_transaction = {source_binding = source_binding,
  claim_deadline = claim_deadline, inspect = inspect}
return M
