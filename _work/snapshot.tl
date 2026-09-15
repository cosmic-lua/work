--- One validated ordinary commit as a complete native-board publication.
---
--- This module owns no transport and accepts only a final-board commit whose
--- caller has already run the board validator and derived the claim deadline.
--- The resulting plan is one immutable, single-parent local Git commit.
local git = require("_work.singlehead_git")
local literal = require("_work.singlehead_literal")
local objects = require("_work.stateplan_objects")
local projection = require("_work.stateplan_git")
local trailers = require("_work.stateplan_trailers")
local tx = require("_work.statetransaction")

local FORMAT < const > = "gitboard-snapshot-plan-v1"

local record Destination
  repository: string
  branch: string
  remote: string
  target_url: string
end

local record Author
  name: string
  email: string
  date: string
end

local record Identity
  parent: string
  tree: string
  message: string
  author: Author
end

local record Plan
  format: string
  destination: Destination
  local_commit: string
  parent: string
  base_tree: string
  tree: string
  message: string
  author: Author
  publish_by: integer
  entries: {{string: any}}
  complete_tree: boolean
end

local function destination_ok(value: Destination): boolean, string
  if objects.checked_repository(value.repository) ~= value.repository
  or objects.checked_branch(value.branch) ~= value.branch
  or value.remote == "" or value.remote:find("[%s%z]")
  or value.target_url == "" or value.target_url:find("[%z\r\n]") then
    return false, "invalid snapshot destination"
  end
  return true, ""
end

local function git_date_ok(value: string): boolean
  local epoch, hour, minute = value:match("^(%-?%d+) [+-](%d%d)(%d%d)$")
  return epoch ~= nil and math.tointeger(tonumber(epoch)) ~= nil
  and tonumber(hour) <= 23 and tonumber(minute) <= 59
end

local function author_ok(value: Author): boolean
  return value.name ~= "" and value.email ~= "" and value.date ~= ""
  and value.name:find("[\n\r<>]") == nil
  and value.email:find("[\n\r<>]") == nil
  and value.date:find("[\n\r]") == nil
  and git_date_ok(value.date)
end

--- Read the canonical logical author carried by an ordinary board commit.
--- Exactly one trailer is required; the obsolete Transaction identity is
--- refused because a snapshot commit is itself the publication identity.
local function logical_author(message: string): Author | nil, string
  local block, err = trailers.parse(message)
  if block == nil then return nil, err end
  local encoded: string | nil = nil
  local count = 0
  for line in block:gmatch("([^\n]+)") do
    local key, value = line:match("^([^:]+):%s*(.*)$")
    if key ~= nil and key:lower() == "transaction" then
      return nil, "snapshot message carries obsolete Transaction trailer"
    end
    if key ~= nil and key:lower() == "gitboard-author" then
      encoded, count = value, count + 1
    end
  end
  if count ~= 1 or encoded == nil then
    return nil, "snapshot message requires exactly one Gitboard-Author trailer"
  end
  local decoded, derr = literal.decode_object(encoded .. "\n")
  if decoded == nil then return nil, "invalid snapshot logical author: " .. derr end
  local author = decoded as Author -- cast: protected untrusted literal shape
  local ran, valid = pcall(author_ok, author)
  local canonical = literal.encode(decoded)
  if not ran or not valid or canonical == nil
  or canonical:gsub("\n$", "") ~= encoded then
    return nil, "invalid snapshot logical author"
  end
  return author, ""
end

--- Exact commit identity independent of provider-selected physical authorship.
local function commit_identity(root: string, sha: string): Identity | nil, string
  if not objects.checked_sha(sha, false) then
    return nil, "invalid snapshot commit ID"
  end
  local raw, err = git.run(root, {"cat-file", "commit", sha})
  if raw == nil then return nil, err end
  local header, message = raw:match("^(.-)\n\n(.*)$")
  if header == nil or message == nil then
    return nil, "malformed snapshot commit"
  end
  local tree = header:match("^tree ([0-9a-f]+)\n")
  local parents: {string} = {}
  for parent in header:gmatch("\nparent ([0-9a-f]+)") do
    parents[#parents + 1] = parent
  end
  if tree == nil or #parents ~= 1 then
    return nil, "snapshot commit must have exactly one parent"
  end
  local author, aerr = logical_author(message)
  if author == nil then return nil, aerr end
  return {parent = parents[1], tree = tree, message = message, author = author}, ""
end

local function same_author(a: Author, b: Author): boolean
  return a.name == b.name and a.email == b.email and a.date == b.date
end

local function author_time(author: Author): integer | nil, string
  local authored = math.tointeger(tonumber(author.date:match("^(%-?%d+)")))
  if authored == nil then return nil, "snapshot author date is invalid" end
  return authored, ""
end

local function identity_matches(root: string, candidate: string,
    plan: Plan): boolean, string
  local identity, err = commit_identity(root, candidate)
  if identity == nil then return false, err end
  if identity.parent ~= plan.parent or identity.tree ~= plan.tree
  or identity.message ~= plan.message or not same_author(identity.author, plan.author) then
    return false, "saved publication candidate differs from frozen snapshot"
  end
  return true, ""
end

local function object_present(root: string, sha: string): boolean
  local ok = git.probe(root, {"cat-file", "-e", sha .. "^{commit}"})
  return ok
end

local function validate(plan: Plan): boolean, string
  if plan.format ~= FORMAT then return false, "unsupported snapshot plan" end
  local ok, derr = destination_ok(plan.destination)
  if not ok then return false, derr end
  if not objects.checked_sha(plan.local_commit, false)
  or not objects.checked_sha(plan.parent, false)
  or not objects.checked_sha(plan.base_tree, false)
  or not objects.checked_sha(plan.tree, false)
  or plan.publish_by < 0 or not author_ok(plan.author) then
    return false, "invalid snapshot plan identity"
  end
  local author, aerr = logical_author(plan.message)
  if author == nil or not same_author(author, plan.author) then
    return false, aerr ~= "" and aerr or "snapshot logical author differs"
  end
  if not literal.is_sequence(plan.entries) then return false, "snapshot entries must be a sequence" end
  local prior = ""
  for _, entry in ipairs(plan.entries) do
    local path, mode, kind = entry.path, entry.mode, entry["type"]
    if not (path is string) or not tx.path_ok(path) or path <= prior
    or (mode ~= "100644" and mode ~= "100755" and mode ~= "120000")
    or kind ~= "blob" then return false, "invalid snapshot tree entry" end
    local content, sha = entry.content, entry.sha
    if (content is string) == (sha is string)
    or (sha is string and not objects.checked_sha(sha, false)) then
      return false, "snapshot tree entry needs exactly one content or SHA"
    end
    prior = path
  end
  return true, ""
end

--- Re-read the local object and prove every saved publication byte.
local function validate_local(root: string, plan: Plan, known_identity?: Identity,
    known_changes?: {tx.Change}): boolean, string
  local ok, err = validate(plan)
  if not ok then return false, err end
  local identity, ierr = known_identity, ""
  if identity == nil then identity, ierr = commit_identity(root, plan.local_commit) end
  if identity == nil then return false, ierr end
  if identity.parent ~= plan.parent then return false, "snapshot local commit has different parent" end
  if identity.tree ~= plan.tree then return false, "snapshot local commit has different tree" end
  local base_tree, berr = git.oid(root, plan.parent .. "^{tree}")
  if base_tree == nil then return false, berr end
  if base_tree ~= plan.base_tree then return false, "snapshot parent has different tree" end
  if identity.message ~= plan.message then return false, "snapshot local commit has different message" end
  if not same_author(identity.author, plan.author) then return false, "snapshot local commit has different logical author" end
  local physical, perr = git.run(root, {"cat-file", "commit", plan.local_commit})
  if physical == nil then return false, perr end
  local name, email, date = physical:match("\nauthor (.-) <([^>]+)> ([^\n]+)\n")
  if name ~= plan.author.name or email ~= plan.author.email or date ~= plan.author.date then
    return false, "snapshot local physical author differs from logical author"
  end
  local changes, oerr = known_changes, ""
  if changes == nil then
    local observed: tx.Transition | nil
    observed, oerr = projection.capture(root, plan.parent, plan.local_commit, {})
    if observed == nil then return false, oerr end
    changes = observed.changes
  end
  local entries = literal.sequence() as {{string: any}} -- cast: connector sequence
  if plan.complete_tree then
    local captured, eerr = projection.snapshot(root, plan.local_commit, changes)
    if captured == nil then return false, eerr end
    entries = captured
  else
    for _, change in ipairs(changes) do
      if change.delete then return false, "delta snapshot cannot carry a deletion" end
      entries[#entries + 1] = {path = change.path, mode = change.mode,
        type = "blob", content = change.content}
    end
  end
  if literal.encode(entries) ~= literal.encode(plan.entries) then
    return false, "snapshot saved tree entries differ from local commit"
  end
  return true, ""
end

local function capture_validated(root: string, local_commit: string,
    destination: Destination, publish_by: integer, known_identity?: Identity,
    known_changes?: {tx.Change}): Plan | nil, string
  local identity, err = known_identity, ""
  if identity == nil then identity, err = commit_identity(root, local_commit) end
  if identity == nil then return nil, err end
  local changes, oerr = known_changes, ""
  if changes == nil then
    local observed: tx.Transition | nil
    observed, oerr = projection.capture(root, identity.parent, local_commit, {})
    if observed == nil then return nil, oerr end
    changes = observed.changes
  end
  if #changes == 0 then return nil, "snapshot has no meaningful final-state change" end
  local complete = false
  for _, change in ipairs(changes) do if change.delete then complete = true end end
  local entries = literal.sequence() as {{string: any}} -- cast: connector sequence
  if complete then
    local captured, eerr = projection.snapshot(root, local_commit, changes)
    if captured == nil then return nil, eerr end
    entries = captured
  else
    for _, change in ipairs(changes) do
      entries[#entries + 1] = {path = change.path, mode = change.mode,
        type = "blob", content = change.content}
    end
  end
  local base_tree, berr = git.oid(root, identity.parent .. "^{tree}")
  if base_tree == nil then return nil, berr end
  local plan: Plan = {format = FORMAT, destination = destination,
    local_commit = local_commit, parent = identity.parent, base_tree = base_tree,
    tree = identity.tree, message = identity.message, author = identity.author,
    publish_by = publish_by,
    entries = entries, complete_tree = complete}
  local ok, verr = validate_local(root, plan, identity, changes)
  if not ok then return nil, verr end
  return plan, ""
end

local function summary_message(summary: string, author: Author): string | nil, string
  if summary == "" or summary:find("%z") then return nil, "snapshot summary is empty or invalid" end
  local parsed, err = trailers.parse(summary)
  if parsed == nil then return nil, err end
  for line in parsed:gmatch("([^\n]+)") do
    local key = line:match("^([^:]+):")
    if key ~= nil and (key:lower() == "transaction" or key:lower() == "gitboard-author") then
      return nil, "snapshot summary supplies a reserved publication trailer"
    end
  end
  local encoded = literal.encode(author)
  if encoded == nil then return nil, "cannot encode snapshot logical author" end
  return summary:gsub("\n*$", "") .. "\n\nGitboard-Author: "
  .. encoded:gsub("\n$", "") .. "\n", ""
end

local record Module
  type Destination = Destination
  type Author = Author
  type Identity = Identity
  type Plan = Plan
  FORMAT: string
  validate: function(Plan): boolean, string
  validate_local: function(string, Plan, known_identity?: Identity,
  known_changes?: {tx.Change}): boolean, string
  commit_identity: function(string, string): Identity | nil, string
  author_time: function(Author): integer | nil, string
  identity_matches: function(string, string, Plan): boolean, string
  object_present: function(string, string): boolean
  message: function(string, Author): string | nil, string
  capture_validated: function(string, string, Destination, integer,
  known_identity?: Identity, known_changes?: {tx.Change}): Plan | nil, string
end

local M: Module = {FORMAT = FORMAT, validate = validate,
  validate_local = validate_local, commit_identity = commit_identity,
  author_time = author_time, identity_matches = identity_matches,
  object_present = object_present,
  message = summary_message,
  capture_validated = capture_validated}
return M
